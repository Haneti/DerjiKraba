using Avalonia.Controls;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.ViewModels;

namespace AvaloniaApplication1.Views
{
    /// <summary>
    /// View для отображения карты с местоположением заказа
    /// </summary>
    public partial class OrderMapView : UserControl
    {
        public OrderMapView()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Установить заказ для отображения на карте
        /// </summary>
        public void SetOrder(Order order)
        {
            if (DataContext is OrderMapViewModel vm)
            {
                vm.SetOrder(order);
            }
        }

        /// <summary>
        /// Обновить карту
        /// </summary>
        public void Refresh()
        {
            if (DataContext is OrderMapViewModel vm)
            {
                vm.Refresh();
            }
        }
    }
}
