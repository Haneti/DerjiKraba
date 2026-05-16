import SwiftUI

struct SupportHomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int> = .constant(3)) {
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            if let user = appState.currentUser {
                if user.isEmployee {
                    SupportConversationsView()
                } else {
                    SupportChatView(clientPhone: user.phone, clientName: "Магазин", selectedTab: $selectedTab)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Остались вопросы?")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Задайте их в чате.\nДля этого нужно войти в аккаунт.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        appState.isShowingAuth = true
                    } label: {
                        Text("Войти")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .navigationTitle("Поддержка")
            }
        }
    }
}
