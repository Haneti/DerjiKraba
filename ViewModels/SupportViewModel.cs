using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    public partial class SupportViewModel : ViewModelBase
    {
        public bool HasSelectedConversation => SelectedConversation != null;
        public bool HasNoSelectedConversation => SelectedConversation == null;
        public bool IsNotLoading => !IsLoading;
        private readonly ApiService _apiService;
        private readonly User _currentUser;

        [ObservableProperty]
        private ObservableCollection<SupportConversation> _conversations = new();

        [ObservableProperty]
        private SupportConversation? _selectedConversation;

        partial void OnSelectedConversationChanged(SupportConversation? value)
        {
            OnPropertyChanged(nameof(HasSelectedConversation));
            OnPropertyChanged(nameof(HasNoSelectedConversation));
            Console.WriteLine($"🔔 SelectedConversation changed: {(value?.ClientName ?? "null")}");

            if (value != null)
            {
                _ = SelectConversationAsync(value);
            }
        }

        [ObservableProperty]
        private ObservableCollection<SupportMessage> _messages = new();

        [ObservableProperty]
        private string _messageText = string.Empty;

        [ObservableProperty]
        private bool _isLoading = false;

        [ObservableProperty]
        private string _errorMessage = string.Empty;

        public SupportViewModel(User currentUser)
        {
            _currentUser = currentUser;
            _apiService = new ApiService();
            LoadConversationsCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadConversationsAsync()
        {
            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var conversations = await _apiService.GetConversationsAsync();
                Conversations.Clear();
                foreach (var conversation in conversations)
                {
                    Conversations.Add(conversation);
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка загрузки: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private async Task SelectConversationAsync(SupportConversation? conversation)
        {
            Console.WriteLine($"🔍 Support: Selecting conversation for {conversation?.ClientName ?? "null"}");
            
            if (conversation == null)
            {
                Console.WriteLine("⚠️ Support: Conversation is null, returning");
                return;
            }

            Console.WriteLine($"📱 Client Phone: {conversation.ClientPhone}");
            Console.WriteLine($"💬 Loading messages...");
            IsLoading = true;
            Messages.Clear();

            try
            {
                Console.WriteLine($"🌐 API Call: GetMessagesAsync({conversation.ClientPhone})");
                var messages = await _apiService.GetMessagesAsync(conversation.ClientPhone);
                Console.WriteLine($"✅ Loaded {messages.Count} messages");
                
                // Add messages one by one to avoid collection modification exception
                foreach (var message in messages)
                {
                    Messages.Add(message);
                }
                Console.WriteLine($"💬 Messages displayed: {Messages.Count}");
                Console.WriteLine($"👁 Chat Area IsVisible should be TRUE now (SelectedConversation={SelectedConversation != null})");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error loading messages: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                ErrorMessage = $"Ошибка загрузки сообщений: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private async Task SendMessageAsync()
        {
            if (SelectedConversation == null || string.IsNullOrWhiteSpace(MessageText))
            {
                ErrorMessage = "Введите сообщение";
                return;
            }

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var success = await _apiService.SendMessageAsync(
                    SelectedConversation.ClientPhone,
                    _currentUser.Phone,
                    MessageText.Trim());

                if (success)
                {
                    MessageText = string.Empty;
                    // Reload messages
                    await SelectConversationAsync(SelectedConversation);
                    // Reload conversations list to update last message
                    await LoadConversationsAsync();
                }
                else
                {
                    ErrorMessage = "Ошибка отправки сообщения";
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }
    }
}
