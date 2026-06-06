using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Input;
using AvaloniaApplication1.Models;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    /// <summary>
    /// ViewModel для отображения местоположения заказа с геокодированием
    /// </summary>
    public partial class OrderMapViewModel : ViewModelBase
    {
        private Order? _order;
        private readonly HttpClient _httpClient;
        private const string YandexApiKey = "0c6cefa6-303e-4c63-a6b6-fd9f3e427a5a";

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

        [ObservableProperty]
        private string _geocodedAddress = "";

        public OrderMapViewModel()
        {
            _httpClient = new HttpClient();
            OpenInBrowserCommand = new RelayCommand(OpenInBrowser);
        }

        public ICommand OpenInBrowserCommand { get; }

        public bool HasError => !string.IsNullOrEmpty(ErrorMessage);
        public bool HasCoordinates => _order?.HasCoordinates ?? false;
        public bool HasAddressDetails => !string.IsNullOrEmpty(Address) || !string.IsNullOrEmpty(Details);
        public bool HasDetails => !string.IsNullOrEmpty(Details);
        public bool HasGeocodedAddress => !string.IsNullOrEmpty(GeocodedAddress);

        /// <summary>
        /// Установить заказ для отображения
        /// </summary>
        public void SetOrder(Order order)
        {
            _order = order;
            UpdateDisplayInfo();
            _ = LoadGeocodeAsync();
        }

        private void UpdateDisplayInfo()
        {
            if (_order == null) return;

            Title = _order.DeliveryType == "delivery" ? "Адрес доставки" : "Местоположение";

            if (_order.HasCoordinates)
            {
                CoordinatesText = $"{_order.Latitude:F5}, {_order.Longitude:F5}";
            }
            else
            {
                CoordinatesText = "Нет координат";
            }

            var details = _order.ParsedDeliveryDetails;
            if (details != null)
            {
                Address = details.Address;
                Details = details.FormattedDetails;
                HouseTypeText = details.IsApartment ? "Квартира" : "Частный дом";

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

        private async Task LoadGeocodeAsync()
        {
            if (_order == null || !_order.HasCoordinates)
            {
                ErrorMessage = "Нет координат";
                return;
            }

            IsLoading = true;
            ErrorMessage = null;
            GeocodedAddress = "";

            try
            {
                var lat = _order.Latitude.Value;
                var lon = _order.Longitude.Value;

                // Reverse geocode via Yandex Geocoder API (same endpoint as iOS app)
                var url = $"https://geocode-maps.yandex.ru/1.x/?apikey={YandexApiKey}&geocode={lon:F6},{lat:F6}&format=json&lang=ru_RU&results=1&kind=house";
                var response = await _httpClient.GetStringAsync(url);

                using var doc = JsonDocument.Parse(response);
                var root = doc.RootElement;
                var featureMembers = root
                    .GetProperty("response")
                    .GetProperty("GeoObjectCollection")
                    .GetProperty("featureMember");

                foreach (var member in featureMembers.EnumerateArray())
                {
                    var geoObject = member.GetProperty("GeoObject");
                    var meta = geoObject.GetProperty("metaDataProperty").GetProperty("GeocoderMetaData");
                    var text = meta.GetProperty("text").GetString();
                    if (!string.IsNullOrEmpty(text))
                    {
                        GeocodedAddress = text;
                        Console.WriteLine($"✅ Reverse geocoded address: {text}");
                        break;
                    }
                }

                if (string.IsNullOrEmpty(GeocodedAddress))
                {
                    Console.WriteLine("⚠️ No geocoded address found");
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка геокодирования: {ex.Message}";
                Console.WriteLine($"❌ Geocode error: {ex}");
            }
            finally
            {
                IsLoading = false;
                OnPropertyChanged(nameof(HasError));
                OnPropertyChanged(nameof(HasGeocodedAddress));
                OnPropertyChanged(nameof(HasCoordinates));
            }
        }

        private void OpenInBrowser()
        {
            if (_order == null || !_order.HasCoordinates) return;

            var lat = _order.Latitude.Value;
            var lon = _order.Longitude.Value;

            // Open Yandex Maps with a specific point marker
            var url = $"https://yandex.ru/maps/?whatshere[point]={lon:F6},{lat:F6}&whatshere[zoom]=16&z=16&ll={lon:F6},{lat:F6}";

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
        /// Refresh geocoded address
        /// </summary>
        public void Refresh()
        {
            _ = LoadGeocodeAsync();
        }
    }
}
