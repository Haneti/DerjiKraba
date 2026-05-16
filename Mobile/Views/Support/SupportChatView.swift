import SwiftUI
import Combine
import PhotosUI
import UIKit
import Photos

struct SupportChatView: View {
    let clientPhone: String
    let clientName: String?
    @Binding var selectedTab: Int
    
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    
    
    @State private var messages: [SupportMessageDTO] = []
    @State private var isLoading = false
    @State private var draftText = ""
    @State private var errorMessage: String?
    @State private var chatUpdateTimer: Timer?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var openedImageURL: String?
    @FocusState private var isInputFocused: Bool
    
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init(clientPhone: String, clientName: String?, selectedTab: Binding<Int> = .constant(3)) {
        self.clientPhone = clientPhone
        self.clientName = clientName
        _selectedTab = selectedTab
    }
    
    private var isStaffMode: Bool {
        // Для клиента показываем кнопку выхода
        // Для сотрудника скрываем (он может выйти через навигацию)
        return appState.currentUser?.role == .employee || appState.currentUser?.role == .owner
    }
    
    private var titleText: String {
        if isStaffMode {
            return clientName ?? PhoneFormatter.format(clientPhone)
        }
        return "Поддержка"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            messagesList
            
            Divider()
            
            inputBar
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isInputFocused = false
        }
        .toolbar {
            if !isStaffMode {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedTab = 0
                    } label: {
                        Label("Выйти", systemImage: "chevron.left")
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        markRead()
                    } label: {
                        Label("Прочитано", systemImage: "checkmark.message")
                    }
                }
            }
        }
        .task {
            guard let user = appState.currentUser else {
                dismiss()
                return
            }

            await loadMessages(silent: false)
            startChatAutoRefresh()
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            Task { await loadMessages(silent: true) }
        }
        .onDisappear {
            chatUpdateTimer?.invalidate()
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .fullScreenCover(item: Binding(
            get: { openedImageURL.map(ChatImageURL.init(value:)) },
            set: { if $0 == nil { openedImageURL = nil } }
        )) { item in
            SupportImageFullScreen(urlString: item.value)
        }
    }
    
    private var header: some View {
        HStack {
            Text("Остались вопросы? Задайте их в чате.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages, id: \.id) { msg in
                        SupportMessageBubble(
                            message: msg,
                            isOutgoing: isOutgoing(msg),
                            onOpenImage: { openedImageURL = $0 }
                        )
                        .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isInputFocused = false
            }
            .refreshable { await loadMessages(silent: false) }
            .onChange(of: messages.count) { _, _ in
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo")
                    .foregroundColor(isUploadingImage ? .gray : .blue)
            }
            .disabled(isUploadingImage)

            TextField("Сообщение...", text: $draftText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
            
            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
        .background(Color(.systemBackground))
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            sendImage(newValue)
        }
    }
    
    private var canSend: Bool {
        appState.currentUser != nil && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func isOutgoing(_ msg: SupportMessageDTO) -> Bool {
        if isStaffMode {
            // Для сотрудника входящие — только от клиента
            return msg.senderRole != "client"
        }
        // Для клиента исходящие — его сообщения
        return msg.senderRole == "client"
    }
    
    @MainActor
    private func loadMessages(silent: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let api = APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
            messages = try await api.fetchSupportMessages(phone: clientPhone)
        } catch {
            guard !silent else { return }
            errorMessage = "Не удалось загрузить сообщения: \(error.localizedDescription)"
        }
    }
    
    private func send() {
        guard let user = appState.currentUser else {
            appState.isShowingAuth = true
            return
        }
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Оптимистично очищаем поле ввода
        draftText = ""
        
        Task {
            do {
                let api = APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
                try await api.sendSupportMessage(phone: clientPhone, senderPhone: user.phone, text: text)
                await loadMessages(silent: true)
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось отправить сообщение: \(error.localizedDescription)"
                }
            }
        }
    }

    private func markRead() {
        Task {
            do {
                try await APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
                    .markSupportConversationRead(phone: clientPhone)
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось отметить чат прочитанным: \(error.localizedDescription)"
                }
            }
        }
    }

    private func sendImage(_ item: PhotosPickerItem) {
        guard let user = appState.currentUser else {
            appState.isShowingAuth = true
            return
        }

        isUploadingImage = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let compressed = compressImage(image, maxBytes: 5 * 1024 * 1024) else {
                    throw NSError(domain: "SupportImage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить фото"])
                }

                try await APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
                    .sendSupportImage(phone: clientPhone, senderPhone: user.phone, imageData: compressed)
                await loadMessages(silent: true)
                await MainActor.run {
                    selectedPhoto = nil
                    isUploadingImage = false
                }
            } catch {
                await MainActor.run {
                    selectedPhoto = nil
                    isUploadingImage = false
                    errorMessage = "Не удалось отправить фото: \(error.localizedDescription)"
                }
            }
        }
    }

    private func compressImage(_ image: UIImage, maxBytes: Int) -> Data? {
        var targetImage = image
        let maxSide: CGFloat = 1600
        let longestSide = max(image.size.width, image.size.height)

        if longestSide > maxSide {
            let scale = maxSide / longestSide
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        var quality: CGFloat = 0.85
        while quality >= 0.35 {
            if let data = targetImage.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }

        return targetImage.jpegData(compressionQuality: 0.3).flatMap { $0.count <= maxBytes ? $0 : nil }
    }
    
    private func startChatAutoRefresh() {
        // Авто-обновление каждые 5 секунд при открытом чате
        Task { @MainActor in
            await loadMessages(silent: true)
        }
    }
    
    private struct SupportMessageBubble: View {
        let message: SupportMessageDTO
        let isOutgoing: Bool
        let onOpenImage: (String) -> Void
        
        var body: some View {
            HStack {
                if isOutgoing { Spacer(minLength: 40) }
                
                VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                    if let imageURL = message.imageURL {
                        ChatRemoteImage(urlString: imageURL)
                            .frame(maxWidth: 220, maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                onOpenImage(imageURL)
                            }
                    } else {
                        Text(message.text)
                            .font(.body)
                    }
                    
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(isOutgoing ? .white.opacity(0.75) : .secondary)
                }
                .padding(10)
                .background(isOutgoing ? Color.blue : Color.gray.opacity(0.15))
                .foregroundColor(isOutgoing ? .white : .primary)
                .cornerRadius(12)
                
                if !isOutgoing { Spacer(minLength: 40) }
            }
        }
        
        private func formatTime(_ date: Date) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ru_RU")
            f.dateStyle = .none
            f.timeStyle = .short
            return f.string(from: date)
        }
    }

    private struct ChatRemoteImage: View {
        let urlString: String
        @State private var image: UIImage?

        var body: some View {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                        .frame(width: 160, height: 120)
                }
            }
            .task(id: urlString) {
                await load()
            }
        }

        private func load() async {
            guard let url = URL(string: urlString) else { return }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil

            do {
                let (data, _) = try await URLSession(configuration: config).data(for: request)
                guard let loaded = UIImage(data: data) else { return }
                await MainActor.run {
                    image = loaded
                }
            } catch {
                await MainActor.run {
                    image = nil
                }
            }
        }
    }

    private struct ChatImageURL: Identifiable {
        let value: String
        var id: String { value }
    }

    private struct SupportImageFullScreen: View {
        let urlString: String
        @Environment(\.dismiss) private var dismiss
        @State private var image: UIImage?
        @State private var saveMessage: String?
        @State private var scale: CGFloat = 1
        @State private var lastScale: CGFloat = 1
        @State private var offset: CGSize = .zero
        @State private var lastOffset: CGSize = .zero

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .clipped()
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = min(4, max(1, lastScale * value))
                                        offset = clamped(offset, in: geo.size)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        offset = clamped(offset, in: geo.size)
                                        lastOffset = offset
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        guard scale > 1 else { return }
                                        offset = clamped(
                                            CGSize(width: lastOffset.width + value.translation.width,
                                                   height: lastOffset.height + value.translation.height),
                                            in: geo.size
                                        )
                                    }
                                    .onEnded { _ in
                                        offset = clamped(offset, in: geo.size)
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2
                                    lastScale = 2
                                }
                            }
                    } else {
                        ProgressView()
                            .tint(.white)
                    }

                    HStack(spacing: 18) {
                        Button {
                            saveImage()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                        }
                        .disabled(image == nil)

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
            }
            .task {
                await load()
            }
            .alert("Фото", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage ?? "")
            }
        }

        private func clamped(_ value: CGSize, in size: CGSize) -> CGSize {
            guard scale > 1 else { return .zero }
            let maxX = size.width * (scale - 1) / 2
            let maxY = size.height * (scale - 1) / 2
            return CGSize(
                width: min(max(value.width, -maxX), maxX),
                height: min(max(value.height, -maxY), maxY)
            )
        }

        private func load() async {
            guard let url = URL(string: urlString) else { return }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil

            do {
                let (data, _) = try await URLSession(configuration: config).data(for: request)
                guard let loaded = UIImage(data: data) else { return }
                await MainActor.run { image = loaded }
            } catch {
                await MainActor.run { saveMessage = "Не удалось открыть фото" }
            }
        }

        private func saveImage() {
            guard let image else { return }
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    Task { @MainActor in saveMessage = "Нет доступа к сохранению в Фото" }
                    return
                }

                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    Task { @MainActor in
                        saveMessage = success ? "Фото сохранено" : (error?.localizedDescription ?? "Не удалось сохранить фото")
                    }
                }
            }
        }
    }
}

