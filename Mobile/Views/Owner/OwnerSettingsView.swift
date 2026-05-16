import SwiftUI

struct StaffUser: Identifiable, Equatable {
    let id: String
    let phone: String
    let firstName: String
    let lastName: String
    let middleName: String?
    let role: UserRole
    let isVerified: Bool

    init(dto: UserDTO) {
        id = dto.id
        phone = dto.phone
        firstName = dto.firstName
        lastName = dto.lastName
        middleName = dto.middleName
        role = UserRole(apiValue: dto.role)
        isVerified = dto.isVerified
    }

    var fullName: String {
        if let middleName, !middleName.isEmpty {
            return "\(lastName) \(firstName) \(middleName)"
        }
        return "\(lastName) \(firstName)"
    }

    var isOwner: Bool {
        role == .owner
    }
}

// MARK: - OWNER VIEW

struct OwnerSettingsView: View {
    @State private var users: [StaffUser] = []
    @State private var showingAddEmployee = false
    @State private var selectedUserForDelete: StaffUser?
    @State private var errorMessage: String?

    private var staff: [StaffUser] {
        users.filter { $0.role == .employee || $0.role == .owner }
    }

    private var clients: [StaffUser] {
        users.filter { $0.role == .client }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Управление складом") {
                    NavigationLink(destination: InventoryView()) {
                        Label("Инвентаризация", systemImage: "list.clipboard")
                    }
                }

                Section("Сотрудники магазина") {
                    ForEach(staff) { employee in
                        HStack {
                            Image(systemName: employee.isOwner ? "crown.fill" : "person.badge.key.fill")
                                .foregroundColor(employee.isOwner ? .orange : .blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(employee.fullName)
                                Text(PhoneFormatter.format(employee.phone))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(employee.role.rawValue)
                                .font(.caption)
                                .padding(6)
                                .background(employee.isOwner ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                selectedUserForDelete = employee
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                updateRole(employee, role: .client)
                            } label: {
                                Label("Убрать", systemImage: "person.crop.circle.badge.minus")
                            }
                            .tint(.gray)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if employee.role == .employee {
                                Button {
                                    updateRole(employee, role: .owner)
                                } label: {
                                    Label("Владелец", systemImage: "crown.fill")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    updateRole(employee, role: .employee)
                                } label: {
                                    Label("Сотрудник", systemImage: "person.badge.key.fill")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }

                Button("Добавить сотрудника/владельца") {
                    showingAddEmployee = true
                }

                Section("Администрирование") {
                    NavigationLink(destination: UserCleanupView()) {
                        Label("Чистка пользователей", systemImage: "person.crop.circle.badge.xmark")
                    }
                }

                if !clients.isEmpty {
                    Section("Клиенты") {
                        ForEach(clients) { client in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.fullName)
                                Text(PhoneFormatter.format(client.phone))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    selectedUserForDelete = client
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    updateRole(client, role: .employee)
                                } label: {
                                    Label("Сотрудник", systemImage: "person.badge.key.fill")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Персонал")
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("Удалить пользователя из БД?", isPresented: Binding(
                get: { selectedUserForDelete != nil },
                set: { if !$0 { selectedUserForDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    deleteUser()
                }
                Button("Отмена", role: .cancel) {
                    selectedUserForDelete = nil
                }
            } message: {
                Text(selectedUserForDelete.map { "\($0.fullName), \(PhoneFormatter.format($0.phone))" } ?? "")
            }
            .sheet(isPresented: $showingAddEmployee, onDismiss: {
                Task { await loadUsers() }
            }) {
                AddEmployeeView()
            }
        }
        .task {
            await loadUsers()
        }
    }

    private func loadUsers() async {
        do {
            let api = APIClient()
            let result = try await api.fetchUsers()
            await MainActor.run {
                users = result.map(StaffUser.init)
            }
        } catch {
            print("load users error:", error)
        }
    }

    private func updateRole(_ user: StaffUser, role: UserRole) {
        Task {
            do {
                let updated = try await APIClient().updateUserRole(id: user.id, role: role)
                await MainActor.run {
                    users.removeAll { $0.id == user.id }
                    users.append(StaffUser(dto: updated))
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteUser() {
        guard let user = selectedUserForDelete else { return }
        selectedUserForDelete = nil

        Task {
            do {
                try await APIClient().deleteUser(id: user.id)
                await MainActor.run {
                    users.removeAll { $0.id == user.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - USER CLEANUP

struct UserCleanupView: View {
    @State private var users: [StaffUser] = []
    @State private var selectedUser: StaffUser?
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?

    private var duplicatePhones: Set<String> {
        let groups = Dictionary(grouping: users, by: { String($0.phone.filter(\.isNumber).suffix(10)) })
        return Set(groups.filter { !$0.key.isEmpty && $0.value.count > 1 }.keys)
    }

    var body: some View {
        List {
            Section("Поиск") {
                TextField("ФИО или телефон", text: $searchText)
                    .textInputAutocapitalization(.words)

                if isLoading {
                    ProgressView()
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            if !duplicatePhones.isEmpty {
                Section("Возможные дубли") {
                    ForEach(users.filter { duplicatePhones.contains(String($0.phone.filter(\.isNumber).suffix(10))) }) { user in
                        cleanupRow(user)
                    }
                }
            }

            Section("Пользователи") {
                ForEach(users) { user in
                    cleanupRow(user)
                }
            }
        }
        .navigationTitle("Чистка пользователей")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Удалить запись", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    .disabled(selectedUser == nil || isDeleting)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await searchUsers()
        }
        .onChange(of: searchText) {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                await searchUsers()
            }
        }
        .confirmationDialog("Удалить пользователя из БД?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                deleteSelectedUser()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(selectedUser.map { "\($0.fullName), \(PhoneFormatter.format($0.phone))" } ?? "")
        }
    }

    private func cleanupRow(_ user: StaffUser) -> some View {
        Button {
            selectedUser = user
        } label: {
            HStack {
                Image(systemName: user.role == .owner ? "crown.fill" : user.role == .employee ? "person.badge.key.fill" : "person.fill")
                    .foregroundColor(user.role == .owner ? .orange : user.role == .employee ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                    Text("\(PhoneFormatter.format(user.phone)) • \(user.role.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if selectedUser == user {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private func searchUsers() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let result = try await APIClient().fetchUsers(search: query.isEmpty ? nil : query)
            await MainActor.run {
                users = result.map(StaffUser.init)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                users = []
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteSelectedUser() {
        guard let selectedUser else { return }
        isDeleting = true

        Task {
            do {
                try await APIClient().deleteUser(id: selectedUser.id)
                await MainActor.run {
                    users.removeAll { $0.id == selectedUser.id }
                    self.selectedUser = nil
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - ADD EMPLOYEE

struct AddEmployeeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var users: [StaffUser] = []
    @State private var selectedUser: StaffUser?

    @State private var lastName = ""
    @State private var firstName = ""
    @State private var middleName = ""
    @State private var phoneInput = ""

    @State private var targetRole: UserRole = .employee

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        PhoneFormatter.isValid(phoneInput) &&
        !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Поиск в базе") {
                    TextField("Напишите Фамилию/Имя/Отчество или телефон", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.default)

                    if isLoading {
                        ProgressView()
                    } else if users.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Пользователь не найден")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(users) { user in
                            Button {
                                fill(user)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.fullName)
                                        Text(PhoneFormatter.format(user.phone))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedUser == user {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Данные") {
                    TextField("Фамилия", text: $lastName)
                    TextField("Имя", text: $firstName)
                    TextField("Отчество", text: $middleName)
                }

                Section("Телефон") {
                    TextField("Телефон", text: $phoneInput)
                        .keyboardType(.phonePad)
                }

                Section("Роль") {
                    Picker("Роль", selection: $targetRole) {
                        Text(UserRole.employee.rawValue).tag(UserRole.employee)
                        Text(UserRole.owner.rawValue).tag(UserRole.owner)
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Назначить роль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .task {
                await searchUsers()
            }
            .onChange(of: searchText) {
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    await searchUsers()
                }
            }
        }
    }

    private func searchUsers() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await MainActor.run {
                users = []
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let api = APIClient()
            let result = try await api.fetchUsers(search: query)
            await MainActor.run {
                users = result.map(StaffUser.init)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                users = []
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func fill(_ user: StaffUser) {
        selectedUser = user
        firstName = user.firstName
        lastName = user.lastName
        middleName = user.middleName ?? ""
        phoneInput = String(user.phone.filter(\.isNumber).suffix(10))
    }

    private func save() {
        let phone = PhoneFormatter.normalize(phoneInput)
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let api = APIClient()
                _ = try await api.createStaff(
                    phone: phone,
                    firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    middleName: middleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : middleName.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: targetRole.apiValue
                )
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
