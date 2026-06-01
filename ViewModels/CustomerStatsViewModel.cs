using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;

namespace AvaloniaApplication1.ViewModels
{
    public partial class CustomerStatsViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        private readonly string _userId;

        [ObservableProperty]
        private string _customerName = "";

        [ObservableProperty]
        private string _phone = "";

        [ObservableProperty]
        private int _totalOrders = 0;

        [ObservableProperty]
        private decimal _totalSpent = 0;

        [ObservableProperty]
        private Order? _lastOrder;

        [ObservableProperty]
        private ObservableCollection<Order> _orders = new();

        [ObservableProperty]
        private bool _isLoading = false;

        [ObservableProperty]
        private string _errorMessage = string.Empty;

        public CustomerStatsViewModel(string userId, string customerName, string phone, ApiService apiService)
        {
            _userId = userId;
            _customerName = customerName;
            _phone = phone;
            _apiService = apiService;
            _ = LoadAsync();
        }

        private async Task LoadAsync()
        {
            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var orders = await _apiService.GetOrdersByUserAsync(_userId);
                Orders = new ObservableCollection<Order>(orders.OrderByDescending(o => o.OrderDate));
                TotalOrders = orders.Count;
                TotalSpent = orders.Sum(o => o.TotalAmount);
                LastOrder = orders.OrderByDescending(o => o.OrderDate).FirstOrDefault();
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
    }
}
