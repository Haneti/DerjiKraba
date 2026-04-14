using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    public partial class OrdersViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        private readonly User _currentUser;

        [ObservableProperty]
        private ObservableCollection<Order> _orders = new();

        [ObservableProperty]
        private Order? _selectedOrder;

        [ObservableProperty]
        private bool _isLoading = false;

        [ObservableProperty]
        private string _errorMessage = string.Empty;

        [ObservableProperty]
        private bool _hasOrders = false;

        [ObservableProperty]
        private string _filterStatus = "all";

        public OrdersViewModel(User currentUser)
        {
            _currentUser = currentUser;
            _apiService = new ApiService();
            LoadOrdersCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadOrdersAsync()
        {
            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var orders = await _apiService.GetOrdersAsync();
                Orders.Clear();
                foreach (var order in orders)
                {
                    Orders.Add(order);
                }
                HasOrders = Orders.Count > 0;
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка загрузки: {ex.Message}";
                HasOrders = false;
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private async Task UpdateOrderStatusAsync(string status)
        {
            if (SelectedOrder == null) return;

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var success = await _apiService.UpdateOrderStatusAsync(SelectedOrder.Id, status);
                if (success)
                {
                    SelectedOrder.Status = status;
                    // Reload orders to refresh the list
                    await LoadOrdersAsync();
                }
                else
                {
                    ErrorMessage = "Ошибка обновления статуса";
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

        partial void OnSelectedOrderChanged(Order? value)
        {
            ErrorMessage = string.Empty;
        }
    }
}
