using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;
using System.Windows.Input;
using Avalonia.Media.Imaging;
using AvaloniaApplication1.Models;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    /// <summary>
    /// ViewModel для отображения карты с местоположением заказа
    /// </summary>
    public partial class OrderMapViewModel : ViewModelBase
    {
        private Order? _order;
        private readonly HttpClient _httpClient;

        [ObservableProperty]
        private Bitmap? _mapImage;

        [ObservableProperty]
        private bool _isLoading;

        [ObservableProperty]
        private string? _errorMessage;

        [ObservableProperty]
        private string _title = "Местоположение";

        [ObservableProperty]
        private string _address = "";

        [ObservableProperty]
        private string _details = "";

        [ObservableProperty]
        private string _houseTypeText = "";

        [ObservableProperty]
        private string _coordinatesText = "";

        public OrderMapViewModel()
        {
            _httpClient = new HttpClient();
            OpenInBrowserCommand = new RelayCommand(OpenInBrowser);
        }

        public ICommand OpenInBrowserCommand { get; }

        /// <summary>
        /// Установить заказ для отображения на карте
        /// </summary>
        public void SetOrder(Order order)
        {
            _order = order;
            UpdateDisplayInfo();
            _ = LoadMapAsync();
        }

        public bool HasMapImage => MapImage != null;
        public bool HasError => !string.IsNullOrEmpty(ErrorMessage);
        public bool HasCoordinates => _order?.HasCoordinates ?? false;
        public bool HasAddressDetails => !string.IsNullOrEmpty(Address) || !string.IsNullOrEmpty(Details);
        public bool HasDetails => !string.IsNullOrEmpty(Details);

        private void UpdateDisplayInfo()
        {
            if (_order == null) return;

            Title = _order.DeliveryType == "delivery" ? "Адрес доставки" : "Местоположение";

            // Set coordinates text
            if (_order.HasCoordinates)
            {
                CoordinatesText = $"{_order.Latitude:F5}, {_order.Longitude:F5}";
            }
            else
            {
                CoordinatesText = "Нет координат";
            }

            // Get address from delivery_details if available
            var details = _order.ParsedDeliveryDetails;
            if (details != null)
            {
                Address = details.Address;
                Details = details.FormattedDetails;
                HouseTypeText = details.IsApartment ? "Квартира" : "Частный дом";

                // Use coordinates from delivery_details as fallback
                if (!_order.HasCoordinates && details.Latitude.HasValue && details.Longitude.HasValue)
                {
                    _order.Latitude = details.Latitude;
                    _order.Longitude = details.Longitude;
                }
            }
            else
            {
                Address = _order.DeliveryAddress ?? "";
                Details = "";
                HouseTypeText = "";
            }
        }

        private async Task LoadMapAsync()
        {
            if (_order == null || !_order.HasCoordinates)
            {
                ErrorMessage = "Нет координат для отображения карты";
                return;
            }

            IsLoading = true;
            ErrorMessage = null;
            MapImage = null;

            try
            {
                // Use static map from Yandex Maps
                var lat = _order.Latitude.Value;
                var lon = _order.Longitude.Value;

                // Try Yandex Static Maps first
                var yandexUrl = $"https://static-maps.yandex.ru/1.x/?ll={lon:F6},{lat:F6}&z=16&l=map&pt={lon:F6},{lat:F6},pm2rdl&size=600,400";

                try
                {
                    var imageBytes = await _httpClient.GetByteArrayAsync(yandexUrl);
                    using var stream = new MemoryStream(imageBytes);
                    MapImage = new Bitmap(stream);
                    Console.WriteLine($"✅ Loaded Yandex map for order");
                }
                catch (Exception yandexEx)
                {
                    Console.WriteLine($"⚠️ Yandex maps failed: {yandexEx.Message}");

                    // Fallback to OpenStreetMap static tiles
                    var osmUrl = $"https://staticmap.openstreetmap.de/staticmap.php?center={lat:F6},{lon:F6}&zoom=16&size=600x400&markers={lat:F6},{lon:F6},red-pushpin";

                    try
                    {
                        var imageBytes = await _httpClient.GetByteArrayAsync(osmUrl);
                        using var stream = new MemoryStream(imageBytes);
                        MapImage = new Bitmap(stream);
                        Console.WriteLine($"✅ Loaded OSM map for order");
                    }
                    catch (Exception osmEx)
                    {
                        throw new Exception($"Failed to load map from both providers. Yandex: {yandexEx.Message}, OSM: {osmEx.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Не удалось загрузить карту: {ex.Message}";
                Console.WriteLine($"❌ Map loading error: {ex}");
            }
            finally
            {
                IsLoading = false;
                OnPropertyChanged(nameof(HasMapImage));
                OnPropertyChanged(nameof(HasError));
                OnPropertyChanged(nameof(HasCoordinates));
            }
        }

        private void OpenInBrowser()
        {
            if (_order == null || !_order.HasCoordinates) return;

            var lat = _order.Latitude.Value;
            var lon = _order.Longitude.Value;

            // Open Yandex Maps
            var url = $"https://yandex.ru/maps/?ll={lon:F6},{lat:F6}&z=16&pt={lon:F6},{lat:F6}";

            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = url,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Failed to open browser: {ex.Message}");
            }
        }

        /// <summary>
        /// Refresh map image
        /// </summary>
        public void Refresh()
        {
            _ = LoadMapAsync();
        }
    }
}
