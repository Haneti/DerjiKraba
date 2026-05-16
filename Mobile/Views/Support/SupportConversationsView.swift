import SwiftUI
import Combine

struct SupportConversationsView: View {
    @State private var conversations: [SupportConversationDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedConversation: SupportConversationDTO?
    @Environment(\.scenePhase) private var scenePhase

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var pendingCount: Int {
        conversations.filter { $0.needsStaffReply }.count
    }

    var body: some View {
        List {
            if pendingCount > 0 {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .foregroundColor(.red)
                        Text("Есть вопросы без ответа: \(pendingCount)")
                            .font(.subheadline)
                    }
                }
            }

            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if conversations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 34))
                            .foregroundColor(.gray)
                        Text("Чатов пока нет")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(conversations, id: \.clientPhone) { conv in
                        Button {
                            selectedConversation = conv
                        } label: {
                            SupportConversationRow(conversation: conv)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if conv.needsStaffReply {
                                Button {
                                    markRead(conv)
                                } label: {
                                    Label("Прочитано", systemImage: "checkmark.message")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedConversation) { conv in
            SupportChatView(clientPhone: conv.clientPhone, clientName: conv.clientName)
        }
        .navigationTitle("Поддержка")
        .task { await load() }
        .refreshable { await load() }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            Task { await load(silent: true) }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func load(silent: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let api = APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
            let convs = try await api.fetchSupportConversations()

            // Сначала те, где нужен ответ, затем остальные. Внутри — по времени.
            conversations = convs.sorted { a, b in
                if a.needsStaffReply != b.needsStaffReply {
                    return a.needsStaffReply && !b.needsStaffReply
                }
                return (a.lastMessageAt ?? .distantPast) > (b.lastMessageAt ?? .distantPast)
            }
        } catch {
            if !silent {
                errorMessage = "Не удалось загрузить чаты: \(error.localizedDescription)"
            }
        }
    }

    private func markRead(_ conversation: SupportConversationDTO) {
        Task {
            do {
                try await APIClient(baseURL: URL(string: "https://derji-kraba.ru/api")!)
                    .markSupportConversationRead(phone: conversation.clientPhone)
                await load()
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось отметить чат прочитанным: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct SupportConversationRow: View {
    let conversation: SupportConversationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(conversation.needsStaffReply ? Color.red : Color.gray.opacity(0.25))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.clientName)
                    .font(.headline)

                Text(PhoneFormatter.format(conversation.clientPhone))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let text = conversation.lastMessageText, !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Нет сообщений")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let d = conversation.lastMessageAt {
                Text(format(date: d))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func format(date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}
