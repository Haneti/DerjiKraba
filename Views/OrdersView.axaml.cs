using Avalonia.Controls;
using Avalonia.Input;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.ViewModels;

namespace AvaloniaApplication1.Views
{
    public partial class OrdersView : UserControl
    {
        public OrdersView()
        {
            InitializeComponent();
        }

        private void OnPhoneDoubleTapped(object? sender, TappedEventArgs e)
        {
            if (sender is Control control && control.Tag is Order order)
            {
                if (DataContext is OrdersViewModel vm)
                {
                    vm.OpenCustomerStatsCommand.Execute(order.UserId);
                }
            }
            e.Handled = true;
        }
    }
}
