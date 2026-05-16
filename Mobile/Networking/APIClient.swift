//
//  APIClient.swift
//  DerjiKraba
//
//  Created by Agent on 27.11.2025.
//

import Foundation

struct ProductDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String
    let pricePerKg: Double
    let quantityInStock: Double
    let deliveryDate: Date
    let expiryDate: Date
    let description: String?
    let isAvailable: Bool
    let unitType: String
    let imageURL: String?
    let imageHash: String?
}

// MARK: - Support chat
struct SupportConversationDTO: Decodable, Identifiable, Hashable {
    let clientPhone: String
    let clientName: String
    let lastMessageAt: Date?
    let lastMessageText: String?
    let lastSenderRole: String?
    let needsStaffReply: Bool

    var id: String { clientPhone }
}

struct SupportMessageDTO: Decodable {
    let id: String
    let clientPhone: String
    let senderPhone: String
    let senderRole: String
    let text: String
    let createdAt: Date

    var imageURL: String? {
        let prefix = "[[image]]"
        guard text.hasPrefix(prefix) else { return nil }
        return String(text.dropFirst(prefix.count))
    }
}

struct OrderItemIn: Encodable { let product_id: String; let quantity: Double; let price_per_kg: Double }
struct CreateOrderIn: Encodable {
    let user_id: String
    let delivery_type: String
    let delivery_address: String?
    let notes: String?
    let items: [OrderItemIn]
}

struct UserDTO: Decodable {
    let id: String
    let phone: String
    let firstName: String
    let lastName: String
    let middleName: String?
    let role: String
    let isVerified: Bool

    enum CodingKeys: String, CodingKey { case id, phone, firstName, lastName, middleName, role, isVerified }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        phone = try c.decode(String.self, forKey: .phone)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        middleName = try c.decodeIfPresent(String.self, forKey: .middleName)
        role = (try? c.decode(String.self, forKey: .role)) ?? "client"
        if let b = try? c.decode(Bool.self, forKey: .isVerified) {
            isVerified = b
        } else if let i = try? c.decode(Int.self, forKey: .isVerified) {
            isVerified = i != 0
        } else if let s = try? c.decode(String.self, forKey: .isVerified) {
            let lower = s.lowercased()
            isVerified = (lower == "true" || lower == "1")
        } else {
            isVerified = false
        }
    }
}

struct OrderItemDTO: Decodable {
    let id: String
    let productId: String?
    let quantity: Double
    let pricePerKg: Double
    let productName: String?
}

struct OrderCustomerDTO: Decodable {
    let fullName: String
    let phone: String
    let address: String?
}

struct OrderDTO: Decodable {
    let id: String
    let userId: String?
    let orderDate: Date
    let status: String
    let deliveryType: String
    let deliveryAddress: String?
    let totalAmount: Double
    let notes: String?
    let items: [OrderItemDTO]?
    let customer: OrderCustomerDTO?
}

final class APIClient {
    private let baseURL: URL
    private let decoder: JSONDecoder

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let mysqlDateTimeUTC: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    init(baseURL: URL = URL(string: "http://87.225.104.51:3000")!) {
        self.baseURL = baseURL
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()

            // Обычно сервер отдаёт дату строкой
            if let s = try? c.decode(String.self) {
                if let date = APIClient.iso8601WithFractional.date(from: s)
                    ?? APIClient.iso8601NoFractional.date(from: s)
                    ?? APIClient.mysqlDateTimeUTC.date(from: s) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(s)")
            }

            // На всякий случай, если придёт Date
            if let date = try? c.decode(Date.self) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date value")
        }
        self.decoder = d
    }

    func health() async throws -> Bool {
        let (data, resp) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("health"))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    func fetchProducts() async throws -> [ProductDTO] {
        let (data, resp) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("products"))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode([ProductDTO].self, from: data)
    }

    func createOrder(_ payload: CreateOrderIn) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("orders"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    // MARK: - Products (update)
    func updateProduct(id: String,
                       name: String?,
                       category: String?,
                       pricePerKg: Double?,
                       quantityInStock: Double?,
                       deliveryDate: Date?,
                       expiryDate: Date?,
                       description: String?,
                       isAvailable: Bool?,
                       unitType: String?,
                       imageURL: String? = nil,
                       imageHash: String? = nil) async throws -> ProductDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("products").appendingPathComponent(id))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Составляем словарь в snake_case как ожидает сервер
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let category = category { body["category"] = category }
        if let price = pricePerKg { body["price_per_kg"] = price }
        if let qty = quantityInStock { body["quantity_in_stock"] = qty }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = deliveryDate { body["delivery_date"] = iso.string(from: d) }
        if let e = expiryDate { body["expiry_date"] = iso.string(from: e) }
        if let desc = description { body["description"] = desc }
        if let avail = isAvailable { body["is_available"] = avail }
        if let unit = unitType { body["unit_type"] = unit }
        if let imageURL = imageURL { body["image_url"] = imageURL }
        if let imageHash = imageHash { body["image_hash"] = imageHash }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(ProductDTO.self, from: data)
    }
    
    // MARK: - Products (minimal update - only quantity)
    func updateProductMinimal(id: String, body: [String: Any]) async throws -> ProductDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("products").appendingPathComponent(id))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(ProductDTO.self, from: data)
    }

    
    // MARK: - Auth
    func registerUser(phone: String, firstName: String, lastName: String, middleName: String?) async throws -> UserDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = [
            "phone": phone,
            "first_name": firstName,
            "last_name": lastName,
            "middle_name": middleName
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(UserDTO.self, from: data)
    }

    func login(phone: String) async throws -> UserDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/login"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["phone": phone]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { throw NSError(domain: "API", code: 404, userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"])}
        guard code == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(UserDTO.self, from: data)
    }

    /// Request verification code via Telegram
    func requestCode(phone: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/request-code"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["phone": phone])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 {
            throw NSError(domain: "API", code: 404, userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"])
        }
        if code == 400 {
            // Try to parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                if error == "Telegram not linked" {
                    throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Telegram не привязан"])
                }
                throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: error])
            }
            throw URLError(.badServerResponse)
        }
        guard code == 200 else { throw URLError(.badServerResponse) }
    }

    /// Verify code and return user data
    func verifyCode(phone: String, code: String) async throws -> UserDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/verify-code"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["phone": phone, "code": code])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode == 400 {
            throw NSError(domain: "API", code: 400, userInfo: [NSLocalizedDescriptionKey: "Неверный или истёкший код"])
        }
        guard statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(UserDTO.self, from: data)
    }

    // MARK: - Staff
    func createStaff(phone: String, firstName: String, lastName: String, middleName: String?, role: String = "employee") async throws -> UserDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("staff/create"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = [
            "phone": phone,
            "first_name": firstName,
            "last_name": lastName,
            "middle_name": middleName,
            "role": role
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(UserDTO.self, from: data)
    }

    // MARK: - Orders
    func fetchOrders() async throws -> [OrderDTO] {
        let (data, resp) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("orders"))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode([OrderDTO].self, from: data)
    }

    func fetchOrders(forUser userId: String) async throws -> [OrderDTO] {
        let url = baseURL.appendingPathComponent("orders/user/").appendingPathComponent(userId)
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode([OrderDTO].self, from: data)
    }

    func updateOrderStatus(orderId: String, status: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("orders/").appendingPathComponent(orderId))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    // MARK: - Support chat
    func fetchSupportConversations() async throws -> [SupportConversationDTO] {
        let (data, resp) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("support/conversations"))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode([SupportConversationDTO].self, from: data)
    }

    /// Метаданные диалога (nil, если диалог ещё не создан)
    func fetchSupportConversation(phone: String) async throws -> SupportConversationDTO? {
        let url = baseURL.appendingPathComponent("support/conversations/").appendingPathComponent(phone)
        let (data, resp) = try await URLSession.shared.data(from: url)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return nil }
        guard code == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(SupportConversationDTO.self, from: data)
    }

    func fetchSupportMessages(phone: String) async throws -> [SupportMessageDTO] {
        let url = baseURL.appendingPathComponent("support/conversations/").appendingPathComponent(phone).appendingPathComponent("messages")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode([SupportMessageDTO].self, from: data)
    }

    func markSupportConversationRead(phone: String) async throws {
        let url = baseURL.appendingPathComponent("support/conversations/").appendingPathComponent(phone).appendingPathComponent("read")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
    
    // MARK: - Users
    func fetchUsers(search: String? = nil, criteria: String? = nil) async throws -> [UserDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("users"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let criteria {
            queryItems.append(URLQueryItem(name: "criteria", value: criteria))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, resp) = try await URLSession.shared.data(from: url)

        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode([UserDTO].self, from: data)
    }

    func deleteUser(id: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("users").appendingPathComponent(id))
        req.httpMethod = "DELETE"
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    func updateUserRole(id: String, role: UserRole) async throws -> UserDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("users").appendingPathComponent(id).appendingPathComponent("role"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["role": role.apiValue])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try decoder.decode(UserDTO.self, from: data)
    }

    func sendSupportMessage(phone: String, senderPhone: String, text: String) async throws {
        let url = baseURL.appendingPathComponent("support/conversations/").appendingPathComponent(phone).appendingPathComponent("messages")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "senderPhone": senderPhone,
            "text": text
        ])
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    func sendSupportImage(phone: String, senderPhone: String, imageData: Data) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = baseURL.appendingPathComponent("support/conversations/").appendingPathComponent(phone).appendingPathComponent("images")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "senderPhone", value: senderPhone)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"support.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
}
