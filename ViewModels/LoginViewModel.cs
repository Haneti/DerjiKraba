using System;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using AvaloniaApplication1.Helpers;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    public partial class LoginViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        
        [ObservableProperty]
        private string _phone = string.Empty;
        
        [ObservableProperty]
        private string _firstName = string.Empty;
        
        [ObservableProperty]
        private string _lastName = string.Empty;
        
        [ObservableProperty]
        private string _middleName = string.Empty;
        
        [ObservableProperty]
        private string _verificationCode = string.Empty;
        
        [ObservableProperty]
        private bool _isLoginMode = true;
        
        [ObservableProperty]
        private bool _showVerificationStep = false;
        
        [ObservableProperty]
        private string _errorMessage = string.Empty;
        
        [ObservableProperty]
        private bool _isLoading = false;
        
        [ObservableProperty]
        private User? _currentUser;

        public LoginViewModel()
        {
            _apiService = new ApiService();
        }

        public event Action<User?>? LoginCompleted;

        [RelayCommand]
        private async Task LoginAsync()
        {
            if (string.IsNullOrWhiteSpace(Phone))
            {
                ErrorMessage = "Введите номер телефона";
                return;
            }

            // Normalize phone number before login
            var normalizedPhone = PhoneFormatter.NormalizeForApi(Phone);
            Console.WriteLine($"📞 Login attempt with phone: '{Phone}' → Normalized: '{normalizedPhone}'");

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                // First, fetch user info without authentication
                var user = await _apiService.LoginAsync(normalizedPhone);
                
                if (user != null)
                {
                    Console.WriteLine($"✅ User found: {user.FullName} ({user.Phone}), Role: {user.Role}, Verified: {user.IsVerified}");
                    
                    // Check if user is staff member (admin or employee)
                    if (!user.IsStaff)
                    {
                        Console.WriteLine($"⚠️ Access denied: User {user.Phone} is not a staff member (Role: {user.Role})");
                        ErrorMessage = "Доступ запрещён. Только сотрудники и владельцы могут входить в систему.";
                        IsLoading = false;
                        return;
                    }
                    
                    // Staff must verify via Telegram code - no direct login allowed
                    Console.WriteLine($"🔐 Requiring Telegram verification for staff member: {normalizedPhone}");
                    ShowVerificationStep = true;
                    ErrorMessage = "Требуется подтверждение через Telegram. Код отправлен.";
                    
                    // Request verification code
                    var codeSent = await _apiService.RequestVerificationCodeAsync(normalizedPhone);
                    if (!codeSent)
                    {
                        ErrorMessage = "Ошибка отправки кода подтверждения";
                        ShowVerificationStep = false;
                    }
                }
                else
                {
                    Console.WriteLine($"⚠️ User not found: {normalizedPhone}");
                    ErrorMessage = "Пользователь не найден. Пожалуйста, зарегистрируйтесь.";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Login error: {ex.Message}");
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private void RegisterAsync()
        {
            if (string.IsNullOrWhiteSpace(Phone))
            {
                ErrorMessage = "Введите номер телефона";
                return;
            }

            if (string.IsNullOrWhiteSpace(FirstName) || string.IsNullOrWhiteSpace(LastName))
            {
                ErrorMessage = "Введите имя и фамилию";
                return;
            }

            // Normalize phone number before registration
            var normalizedPhone = PhoneFormatter.NormalizeForApi(Phone);
            Console.WriteLine($"📞 Registration with phone: '{Phone}' → Normalized: '{normalizedPhone}'");

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                // Registration is only for staff - customers are added by admin
                // Show message that they need to contact admin
                Console.WriteLine($"⚠️ Self-registration attempt by: {normalizedPhone}");
                ErrorMessage = "Регистрация недоступна. Обратитесь к администратору для создания учётной записи.";
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Registration error: {ex.Message}");
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private void SwitchToRegister()
        {
            IsLoginMode = false;
            ErrorMessage = string.Empty;
        }

        [RelayCommand]
        private void SwitchToLogin()
        {
            IsLoginMode = true;
            ShowVerificationStep = false;
            ErrorMessage = string.Empty;
        }

        [RelayCommand]
        private async Task RequestCodeAsync()
        {
            if (string.IsNullOrWhiteSpace(Phone))
            {
                ErrorMessage = "Введите номер телефона";
                return;
            }

            // Normalize phone number before requesting code
            var normalizedPhone = PhoneFormatter.NormalizeForApi(Phone);
            Console.WriteLine($"📞 Request verification code for: '{Phone}' → Normalized: '{normalizedPhone}'");

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var success = await _apiService.RequestVerificationCodeAsync(normalizedPhone);
                
                if (success)
                {
                    Console.WriteLine($"✅ Verification code sent to {normalizedPhone}");
                    ShowVerificationStep = true;
                    ErrorMessage = "Код отправлен в Telegram";
                }
                else
                {
                    Console.WriteLine($"❌ Failed to send verification code");
                    ErrorMessage = "Ошибка отправки кода";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Request code error: {ex.Message}");
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private async Task VerifyCodeAsync()
        {
            if (string.IsNullOrWhiteSpace(VerificationCode))
            {
                ErrorMessage = "Введите код подтверждения";
                return;
            }

            // Normalize phone number before verifying code
            var normalizedPhone = PhoneFormatter.NormalizeForApi(Phone);
            Console.WriteLine($"📞 Verify code for: '{Phone}' → Normalized: '{normalizedPhone}', Code: {VerificationCode}");

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var user = await _apiService.VerifyCodeAsync(normalizedPhone, VerificationCode);
                
                if (user != null)
                {
                    Console.WriteLine($"✅ Code verified successfully: {user.FullName} ({user.Phone}), Role: {user.Role}");
                    
                    // Double-check that user is staff after verification
                    if (!user.IsStaff)
                    {
                        Console.WriteLine($"⚠️ Access denied after verification: User {user.Phone} is not a staff member");
                        ErrorMessage = "Доступ запрещён. Только сотрудники и владельцы могут входить в систему.";
                        ShowVerificationStep = false;
                        IsLoading = false;
                        return;
                    }
                    
                    CurrentUser = user;
                    LoginCompleted?.Invoke(user);
                }
                else
                {
                    Console.WriteLine($"❌ Invalid or expired code");
                    ErrorMessage = "Неверный код или срок действия истек";
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Verify code error: {ex.Message}");
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }
    }
}
