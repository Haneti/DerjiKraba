//
//  ProductDetailView.swift
//  DerjiKraba
//
//  Created by Haneti ⠀ on 19.11.2025.
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    let product: Product
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var quantity: Double = 0.5
    @State private var showingAddedAlert = false
    @State private var isShowingImageFullScreen = false
    
    // Поля редактирования (только для владельца)
    @State private var editName: String = ""
    @State private var editPriceText: String = ""
    @State private var editDeliveryDate: Date = Date()
    @State private var editExpiryDate: Date = Date()
    @State private var editDescription: String = ""
    @State private var editIsHidden: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingImagePicker: Bool = false
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage: Bool = false
    
    private var currentInCart: Double {
        appState.cartItems.first(where: { $0.product?.id == product.id })?.quantity ?? 0
    }
    private var maxAddable: Double {
        max(0, min(10.0, product.quantityInStock) - currentInCart)
    }
    private var sliderUpperBound: Double {
        // Делаем верхнюю границу всегда больше нижней, чтобы избежать краша Slider
        max(0.2, maxAddable)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Изображение товара
                Button {
                    isShowingImageFullScreen = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.1))
                        
                        if let imageURL = product.imageURL, !imageURL.isEmpty {
                            // Если есть URL - загружаем с сервера через кэш
                            CachedAsyncImageView(
                                imageURL: imageURL,
                                placeholderName: nil,
                                imageHash: product.imageHash
                            )
                            .frame(maxWidth: .infinity, maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            // Если нет URL - показываем placeholder из Assets по имени товара
                            ImagePlaceholderView(productName: product.name)
                                .frame(maxWidth: .infinity, maxHeight: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .clipped()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(height: 250)
                .padding(.horizontal)
                
                // Информация о товаре
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(product.category)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(product.pricePerKg)) ₽")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Divider()
                    
                    // Описание
                    if !product.productDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Описание")
                                .font(.headline)
                            Text(product.productDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Информация о свежести
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Информация")
                            .font(.headline)
                        
                        InfoRow(icon: "calendar", title: "Дата поставки", value: formatDate(product.deliveryDate))
                        InfoRow(icon: "clock", title: "Срок годности", value: formatDate(product.expiryDate))
                        InfoRow(icon: "hourglass", title: "До истечения", value: "\(product.daysUntilExpiry) дней", color: product.daysUntilExpiry <= 2 ? .red : .green)
                        InfoRow(icon: "shippingbox", title: "В наличии", value: String(format: "%.1f кг", product.quantityInStock))
                        
                        // Индикатор последней инвентаризации
                        if let lastAdjustment = getLastInventoryAdjustment(for: product.id) {
                            HStack {
                                Image(systemName: "list.clipboard")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                Text("Посл. инвентаризация")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDate(lastAdjustment.createdAt))
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Редактирование товара (только владелец)
                    if appState.currentUser?.isOwner == true {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Управление товаром")
                                .font(.headline)
                            
                            // Кнопка загрузки изображения
                            HStack {
                                Button(action: {
                                    showingImagePicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title2)
                                        VStack(alignment: .leading) {
                                            Text("Загрузить изображение")
                                                .fontWeight(.semibold)
                                            Text(isUploadingImage ? "Загрузка..." : "Нажмите для выбора фото")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if isUploadingImage {
                                            ProgressView()
                                        }
                                    }
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(12)
                                }
                                .disabled(isUploadingImage)
                            }
                            .padding(.vertical, 8)

                            TextField("Название", text: $editName)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Цена за кг", text: $editPriceText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            
                            DatePicker("Дата поставки", selection: $editDeliveryDate, displayedComponents: .date)
                            DatePicker("Срок годности", selection: $editExpiryDate, displayedComponents: .date)
                            
                            Toggle("Скрыть для клиентов", isOn: $editIsHidden)
                            
                            Text("Описание")
                                .font(.subheadline)
                            TextEditor(text: $editDescription)
                                .frame(minHeight: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3))
                                )
                            
                            Button(action: saveProductChanges) {
                                HStack {
                                    Spacer()
                                    Text("Сохранить изменения")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Удалить товар")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.05))
                        .cornerRadius(12)
                    } else if appState.isEmployee {
                        // Для сотрудников показываем кнопку добавления в корзину
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Добавление в корзину")
                                .font(.headline)
                            
                            Text("Как сотрудник, вы можете добавлять товары в корзину для оформления заказов от имени клиентов.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Выбор количества
                VStack(spacing: 16) {
                    HStack {
                        Text("Количество (кг)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1f кг", quantity))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: { decreaseQuantity() }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $quantity, in: 0.1...sliderUpperBound, step: 0.1)
                            .disabled(maxAddable <= 0)
                        
                        Button(action: { increaseQuantity() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Итоговая стоимость
                    if maxAddable <= 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("Достигнут лимит 10 кг для этого товара")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    HStack {
                        Text("Итого:")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.0f ₽", quantity * product.pricePerKg))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.9))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
                .padding(.horizontal)
                
                // Кнопка добавления в корзину
                Button(action: addToCart) {
                    HStack {
                        Image(systemName: "cart.fill.badge.plus")
                        Text("Добавить в корзину")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                .disabled(maxAddable <= 0)
            }
            .padding(.vertical)
        }
        .onAppear {
            // Подстраиваем выбранное количество под допустимые границы
            quantity = min(max(0.1, quantity), sliderUpperBound)
            setupEditFields()
        }
        .onChange(of: maxAddable) { _, _ in
            quantity = min(max(0.1, quantity), sliderUpperBound)
        }
        .fullScreenCover(isPresented: $isShowingImageFullScreen) {
            if let imageURL = product.imageURL, !imageURL.isEmpty {
                // Показываем изображение с сервера
                FullscreenProductImageView(imageURL: imageURL, imageHash: product.imageHash)
            } else {
                // Показываем placeholder из Assets
                FullscreenProductImageView(imageName: product.name)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                uploadImage(image)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
.alert("Добавлено!", isPresented: $showingAddedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(product.name) добавлен в корзину")
        }
        .alert("Удалить товар?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                deleteProduct()
            }
        } message: {
            Text("Это действие нельзя будет отменить")
        }
    }
    
    private func addToCart() {
        let qty = min(quantity, maxAddable)
        guard qty > 0 else { return }
        appState.addToCart(product: product, quantity: qty)
        showingAddedAlert = true
    }
    
    private func setupEditFields() {
        // Инициализация полей редактирования из текущего товара
        editName = product.name
        editPriceText = String(format: "%.0f", product.pricePerKg)
        editDeliveryDate = product.deliveryDate
        editExpiryDate = product.expiryDate
        editDescription = product.productDescription
        editIsHidden = !product.isAvailable
    }
    
    private func saveProductChanges() {
        // Обновляем имя, если поле не пустое
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            product.name = trimmedName
        }

        // Парсим цену
        let normalized = editPriceText.replacingOccurrences(of: ",", with: ".")
        if let newPrice = Double(normalized) {
            product.pricePerKg = newPrice
        }
        product.deliveryDate = editDeliveryDate
        product.expiryDate = editExpiryDate
        product.productDescription = editDescription
        product.isAvailable = !editIsHidden

        // Сначала сохраняем локально
        do {
            try modelContext.save()
        } catch {
            // можно показать алерт — но продолжаем попытку синхронизации
            print("Local save failed:", error)
        }

        // Отправляем на сервер (не блокируем UI)
        Task {
            do {
                let api = APIClient(baseURL: URL(string: "http://87.225.104.51:3000")!)
                let _ = try await api.updateProduct(
                    id: product.id.uuidString,
                    name: product.name,
                    category: product.category,
                    pricePerKg: product.pricePerKg,
                    quantityInStock: product.quantityInStock,
                    deliveryDate: product.deliveryDate,
                    expiryDate: product.expiryDate,
                    description: product.productDescription,
                    isAvailable: product.isAvailable,
                    unitType: product.unitType,
                    imageURL: product.imageURL,
                    imageHash: product.imageHash
                )
                // при желании можно обновить локальную модель ответом сервера
                // но в простом случае локальная уже в нужном состоянии
            } catch {
                // показать ошибку сети пользователю, логировать
                print("Failed to sync product with server:", error)
            }
        }
    }

    
    private func deleteProduct() {
        modelContext.delete(product)
        try? modelContext.save()
        dismiss()
    }
    
    private func uploadImage(_ image: UIImage) {
        isUploadingImage = true
        
        Task {
            do {
                // Загружаем изображение на сервер через ImageUploader
                let (url, hash) = try await ImageUploader.shared.uploadProductImage(
                    image,
                    productID: product.id.uuidString
                )
                
                // Обновляем локальную модель
                await MainActor.run {
                    product.imageURL = url
                    product.imageHash = hash
                    try? modelContext.save()
                    isUploadingImage = false
                    selectedImage = nil
                    
                    // Показываем уведомление об успехе
                    showUploadSuccessAlert()
                }
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                    selectedImage = nil
                    showUploadErrorAlert(error: error.localizedDescription)
                }
            }
        }
    }
    
    private func showUploadSuccessAlert() {
        // Можно добавить alert об успешной загрузке
        print("✅ Изображение успешно загружено")
    }
    
    private func showUploadErrorAlert(error: String) {
        print("❌ Ошибка загрузки: \(error)")
    }
    
    private func increaseQuantity() {
        quantity = min(quantity + 0.5, sliderUpperBound)
    }
    
    private func decreaseQuantity() {
        quantity = max(0.1, quantity - 0.5)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func getLastInventoryAdjustment(for productId: UUID) -> InventoryAdjustment? {
        let descriptor = FetchDescriptor<InventoryAdjustment>(
            predicate: #Predicate { $0.productId == productId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Крабы": return "crab.fill"
        case "Креветки": return "shrimp.fill"
        case "Рыба": return "fish.fill"
        case "Икра": return "circle.fill"
        default: return "circle.fill"
        }
    }
}

struct FullscreenProductImageView: View {
    let imageURL: String?
    let imageName: String?
    let imageHash: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    init(imageURL: String, imageHash: String?) {
        self.imageURL = imageURL
        self.imageName = nil
        self.imageHash = imageHash
    }
    
    init(imageName: String) {
        self.imageURL = nil
        self.imageName = imageName
        self.imageHash = nil
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                Group {
                    if let imageURL = imageURL, !imageURL.isEmpty {
                        CachedAsyncImageView(
                            imageURL: imageURL,
                            placeholderName: nil,
                            imageHash: imageHash,
                            contentMode: .fit
                        )
                        .aspectRatio(contentMode: .fit)
                    } else if let imageName = imageName {
                        ImagePlaceholderView(productName: imageName)
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = min(4.0, max(1.0, lastScale * value))
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
            
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding()
                }
            }
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
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}
