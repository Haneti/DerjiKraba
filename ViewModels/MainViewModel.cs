using System;
using System.Linq;
using System.Threading.Tasks;
using System.Timers;
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

        [ObservableProperty]
        private bool _isRestoringSession = true;

        [ObservableProperty]
        private int _pendingOrdersCount = 0;

        [ObservableProperty]
        private int _pendingSupportCount = 0;

        [ObservableProperty]
        private int _expiredProductsCount = 0;

        [ObservableProperty]
        private bool _hasPendingOrders = false;

        [ObservableProperty]
        private bool _hasPendingSupport = false;

        [ObservableProperty]
        private bool _hasExpiredProducts = false;

        private Timer? _pollTimer;

        public MainViewModel()
        {
            // Initialize theme
            IsDarkMode = ThemeManager.Instance.CurrentTheme == ThemeMode.Dark;
            ThemeManager.Instance.ThemeChanged += (s, mode) =>
            {
                IsDarkMode = mode == ThemeMode.Dark;
            };
            
            _ = RestoreSessionAsync();
        }

        private async Task RestoreSessionAsync()
        {
            try
            {
                var savedUser = await ApiService.LoadSessionAsync();
                if (savedUser != null && !string.IsNullOrEmpty(savedUser.Token) && !string.IsNullOrEmpty(savedUser.SessionKey))
                {
                    // Trust the saved session data — auth/me may not exist on the server.
                    // The first real API call will naturally validate the token.
                    if (savedUser.IsStaff)
                    {
                        OnLoginCompleted(savedUser);
                        Console.WriteLine($"✅ Session restored for {savedUser.FullName}");
                        IsRestoringSession = false;
                        return;
                    }
                    else
                    {
                        Console.WriteLine($"🚫 Saved user is not staff — clearing session");
                        ApiService.ClearSession();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Session restore error: {ex.Message}");
            }
            
            // No valid session — show login screen
            var loginVm = new LoginViewModel();
            loginVm.LoginCompleted += OnLoginCompleted;
            CurrentView = loginVm;
            CurrentViewTitle = "Вход";
            IsRestoringSession = false;
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

                // Start polling for pending items
                StartPendingPoll();
            }
        }

        private void StartPendingPoll()
        {
            _pollTimer?.Dispose();
            _pollTimer = new Timer(30000); // 30 seconds
            _pollTimer.Elapsed += async (s, e) => await CheckPendingAsync();
            _pollTimer.AutoReset = true;
            _pollTimer.Start();
            _ = CheckPendingAsync();
        }

        private void StopPendingPoll()
        {
            _pollTimer?.Stop();
            _pollTimer?.Dispose();
            _pollTimer = null;
        }

        private async Task CheckPendingAsync()
        {
            if (CurrentUser == null) return;

            try
            {
                var api = new ApiService(CurrentUser.Token, CurrentUser.SessionKey);

                // Check orders with status "pending"
                if (ShowOrders)
                {
                    var orders = await api.GetOrdersAsync();
                    var pendingOrders = orders.Count(o => o.Status == "pending");
                    PendingOrdersCount = pendingOrders;
                    HasPendingOrders = pendingOrders > 0;
                }

                // Check support conversations needing staff reply
                if (ShowSupport)
                {
                    var conversations = await api.GetConversationsAsync();
                    var pendingSupport = conversations.Count(c => c.NeedsStaffReply);
                    PendingSupportCount = pendingSupport;
                    HasPendingSupport = pendingSupport > 0;
                }

                // Check expired products
                if (ShowProducts)
                {
                    var products = await api.GetProductsAsync();
                    var expiredCount = products.Count(p => p.IsExpired);
                    ExpiredProductsCount = expiredCount;
                    HasExpiredProducts = expiredCount > 0;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ CheckPending error: {ex.Message}");
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
            StopPendingPoll();
            ApiService.ClearSession();
            CurrentUser = null;
            IsLoggedIn = false;
            ShowProducts = false;
            ShowOrders = false;
            ShowSupport = false;
            ShowInventory = false;
            ShowStaffManagement = false;
            PendingOrdersCount = 0;
            PendingSupportCount = 0;
            ExpiredProductsCount = 0;
            HasPendingOrders = false;
            HasPendingSupport = false;
            HasExpiredProducts = false;
            
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
