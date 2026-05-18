using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Threading.Tasks;
using Avalonia.Platform.Storage;
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
        public bool HasSelectedImage => !string.IsNullOrEmpty(SelectedImagePath);
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

        partial void OnIsLoadingChanged(bool value)
        {
            OnPropertyChanged(nameof(IsNotLoading));
        }

        [ObservableProperty]
        private string _errorMessage = string.Empty;

        [ObservableProperty]
        private string _selectedImagePath = string.Empty;

        partial void OnSelectedImagePathChanged(string value)
        {
            OnPropertyChanged(nameof(HasSelectedImage));
        }

        public SupportViewModel(User currentUser)
        {
            _currentUser = currentUser;
            _apiService = new ApiService(currentUser.Token, currentUser.SessionKey);
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
        private async Task RefreshMessagesAsync()
        {
            if (SelectedConversation == null)
            {
                Console.WriteLine("⚠️ Support: No selected conversation to refresh");
                return;
            }
            
            Console.WriteLine($"🔄 Refreshing messages for {SelectedConversation.ClientName}");
            await LoadMessagesAsync(SelectedConversation);
        }

        private async Task LoadMessagesAsync(SupportConversation conversation)
        {
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
        private async Task SelectConversationAsync(SupportConversation? conversation)
        {
            Console.WriteLine($"🔍 Support: Selecting conversation for {conversation?.ClientName ?? "null"}");
            
            if (conversation == null)
            {
                Console.WriteLine("⚠️ Support: Conversation is null, returning");
                return;
            }

            // Set as selected (this won't close the chat)
            SelectedConversation = conversation;
            
            await LoadMessagesAsync(conversation);
        }

        [RelayCommand]
        private async Task SendMessageAsync()
        {
            if (SelectedConversation == null)
            {
                ErrorMessage = "Выберите диалог";
                return;
            }

            if (string.IsNullOrWhiteSpace(MessageText) && !HasSelectedImage)
            {
                ErrorMessage = "Введите сообщение или выберите изображение";
                return;
            }

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                string? imageUrl = null;
                
                // Upload image if selected
                if (HasSelectedImage)
                {
                    imageUrl = await _apiService.UploadImageAsync(SelectedImagePath);
                    if (string.IsNullOrEmpty(imageUrl))
                    {
                        ErrorMessage = "Ошибка загрузки изображения";
                        IsLoading = false;
                        return;
                    }
                }

                var success = await _apiService.SendMessageAsync(
                    SelectedConversation.ClientPhone,
                    _currentUser.Phone,
                    MessageText.Trim(),
                    imageUrl);

                if (success)
                {
                    MessageText = string.Empty;
                    SelectedImagePath = string.Empty;
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

        [RelayCommand]
        private async Task SelectImageAsync()
        {
            try
            {
                var storageProvider = App.StorageProvider;
                if (storageProvider == null)
                {
                    ErrorMessage = "Не удалось получить доступ к файловой системе";
                    return;
                }

                var options = new FilePickerOpenOptions
                {
                    AllowMultiple = false,
                    FileTypeFilter = new[]
                    {
                        new FilePickerFileType("Images")
                        {
                            Patterns = new[] { "*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp" }
                        }
                    }
                };

                var files = await storageProvider.OpenFilePickerAsync(options);
                if (files != null && files.Count > 0)
                {
                    var file = files[0];
                    SelectedImagePath = file.Path.LocalPath;
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка выбора файла: {ex.Message}";
            }
        }

        [RelayCommand]
        private void ClearSelectedImage()
        {
            SelectedImagePath = string.Empty;
        }
    }
}
