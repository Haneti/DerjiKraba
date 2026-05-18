using System;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    public partial class MainViewModel : ViewModelBase
    {
        [ObservableProperty]
        private ViewModelBase _currentView;

        [ObservableProperty]
        private string _currentViewTitle = string.Empty;

        [ObservableProperty]
        private User? _currentUser;

        [ObservableProperty]
        private bool _isLoggedIn = false;

        [ObservableProperty]
        private bool _showProducts = false;

        [ObservableProperty]
        private bool _showOrders = false;

        [ObservableProperty]
        private bool _showSupport = false;

        [ObservableProperty]
        private bool _showInventory = false;

        [ObservableProperty]
        private bool _showStaffManagement = false;

        [ObservableProperty]
        private bool _isDarkMode = false;

        public MainViewModel()
        {
            CurrentView = new LoginViewModel();
            CurrentViewTitle = "Вход";
            
            // Initialize theme
            IsDarkMode = ThemeManager.Instance.CurrentTheme == ThemeMode.Dark;
            ThemeManager.Instance.ThemeChanged += (s, mode) =>
            {
                IsDarkMode = mode == ThemeMode.Dark;
            };
            
            if (CurrentView is LoginViewModel loginVm)
            {
                loginVm.LoginCompleted += OnLoginCompleted;
            }
            
            _ = RestoreSessionAsync();
        }

        private async Task RestoreSessionAsync()
        {
            try
            {
                var savedUser = await ApiService.LoadSessionAsync();
                if (savedUser != null && !string.IsNullOrEmpty(savedUser.Token) && !string.IsNullOrEmpty(savedUser.SessionKey))
                {
                    var api = new ApiService(savedUser.Token, savedUser.SessionKey);
                    var currentUser = await api.GetCurrentUserAsync();
                    if (currentUser != null && currentUser.IsStaff)
                    {
                        currentUser.Token = savedUser.Token;
                        currentUser.SessionKey = savedUser.SessionKey;
                        OnLoginCompleted(currentUser);
                        Console.WriteLine($"✅ Session restored for {currentUser.FullName}");
                    }
                    else
                    {
                        ApiService.ClearSession();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Session restore error: {ex.Message}");
            }
        }

        private void OnLoginCompleted(User? user)
        {
            if (user != null)
            {
                // Verify user is staff before allowing access
                if (!user.IsStaff)
                {
                    Console.WriteLine($"⚠️ Unauthorized access attempt by {user.Phone} (Role: {user.Role})");
                    CurrentView = new LoginViewModel();
                    CurrentViewTitle = "Вход";
                    return;
                }
                
                CurrentUser = user;
                IsLoggedIn = true;
                
                // Set feature availability based on role
                ShowProducts = true;
                ShowOrders = user.IsStaff;  // Only staff can see orders
                ShowSupport = true;  // All staff can use support
                ShowInventory = user.IsOwner;  // Only owner can do inventory
                ShowStaffManagement = user.Role == "owner";  // Only owner can manage staff
                
                Console.WriteLine($"✅ User {user.FullName} logged in with role {user.Role}");
                Console.WriteLine($"📋 Permissions - Products: {ShowProducts}, Orders: {ShowOrders}, Inventory: {ShowInventory}, Support: {ShowSupport}, Staff Mgmt: {ShowStaffManagement}");
                
                // Navigate to products by default
                NavigateToProducts();
            }
        }

        [RelayCommand]
        private void NavigateToProducts()
        {
            if (CurrentUser == null) return;
            
            CurrentView = new ProductsViewModel(CurrentUser);
            CurrentViewTitle = "Товары";
        }

        [RelayCommand]
        private void NavigateToOrders()
        {
            if (CurrentUser == null || !CurrentUser.IsStaff)
            {
                Console.WriteLine("⚠️ Unauthorized access attempt to Orders");
                return;
            }
                    
            CurrentView = new OrdersViewModel(CurrentUser);
            CurrentViewTitle = "Заказы";
        }
        
        [RelayCommand]
        private void NavigateToSupport()
        {
            if (CurrentUser == null)
            {
                Console.WriteLine("⚠️ Unauthorized access attempt to Support");
                return;
            }
                    
            CurrentView = new SupportViewModel(CurrentUser);
            CurrentViewTitle = "Поддержка";
        }
        
        [RelayCommand]
        private void NavigateToInventory()
        {
            if (CurrentUser == null || !CurrentUser.IsOwner)
            {
                Console.WriteLine($"⚠️ Unauthorized access attempt to Inventory by {CurrentUser?.Role}");
                return;
            }
                    
            CurrentView = new InventoryViewModel(CurrentUser);
            CurrentViewTitle = "Инвентаризация";
        }
        
        [RelayCommand]
        private void NavigateToStaff()
        {
            if (CurrentUser == null || CurrentUser.Role != "owner")
            {
                Console.WriteLine($"⚠️ Unauthorized access attempt to Staff Management by {CurrentUser?.Role}");
                return;
            }
                    
            CurrentView = new StaffViewModel(CurrentUser);
            CurrentViewTitle = "Управление сотрудниками";
        }

        [RelayCommand]
        private void Logout()
        {
            ApiService.ClearSession();
            CurrentUser = null;
            IsLoggedIn = false;
            ShowProducts = false;
            ShowOrders = false;
            ShowSupport = false;
            ShowInventory = false;
            ShowStaffManagement = false;
            
            var loginVm = new LoginViewModel();
            loginVm.LoginCompleted += OnLoginCompleted;
            CurrentView = loginVm;
            CurrentViewTitle = "Вход";
        }

        [RelayCommand]
        private void ToggleTheme()
        {
            ThemeManager.Instance.ToggleTheme();
        }
    }
}
