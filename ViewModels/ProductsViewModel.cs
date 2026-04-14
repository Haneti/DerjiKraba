using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using AvaloniaApplication1.Helpers;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    public partial class ProductsViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        private readonly User _currentUser;

        [ObservableProperty]
        private ObservableCollection<Product> _products = new();

        [ObservableProperty]
        private Product? _selectedProduct;

        [ObservableProperty]
        private bool _isLoading = false;

        [ObservableProperty]
        private string _errorMessage = string.Empty;

        [ObservableProperty]
        private bool _isEditing = false;

        [ObservableProperty]
        private bool _hasProducts = false;

        // Form fields
        [ObservableProperty]
        private string _productName = string.Empty;

        [ObservableProperty]
        private string _category = string.Empty;

        [ObservableProperty]
        private decimal _pricePerKg;

        [ObservableProperty]
        private decimal _quantityInStock;

        [ObservableProperty]
        private DateTime? _deliveryDate;

        [ObservableProperty]
        private DateTime? _expiryDate;

        [ObservableProperty]
        private string _description = string.Empty;

        [ObservableProperty]
        private bool _isAvailable = true;

        [ObservableProperty]
        private string _unitType = "kg";

        partial void OnSelectedProductChanged(Product? value)
        {
            if (value != null)
            {
                // Pre-load image when product is selected
                LoadProductImageAsync(value);
            }
        }

        private async void LoadProductImageAsync(Product product)
        {
            if (!string.IsNullOrEmpty(product.ImageURL))
            {
                var bitmap = await ImageCacheManager.Instance.GetImageAsync(product.ImageURL, product.ImageHash);
                // In a real implementation, you'd update a separate Images dictionary
                // For simplicity, we're relying on the converter
            }
        }

        public ProductsViewModel(User currentUser)
        {
            _currentUser = currentUser;
            _apiService = new ApiService();
            LoadProductsCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadProductsAsync()
        {
            Console.WriteLine($"🚀 Loading products...");
            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var products = await _apiService.GetProductsAsync();
                Products.Clear();
                foreach (var product in products)
                {
                    Products.Add(product);
                }
                HasProducts = Products.Count > 0;
                Console.WriteLine($"✅ Loaded {Products.Count} products");
                Console.WriteLine($"📊 {ImageCacheManager.Instance.GetMemoryCacheStats()}");
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка загрузки: {ex.Message}";
                HasProducts = false;
            }
            finally
            {
                IsLoading = false;
            }
        }

        [RelayCommand]
        private void StartCreate()
        {
            IsEditing = true;
            ClearForm();
        }

        [RelayCommand]
        private void StartEdit(Product? product)
        {
            if (product == null) return;

            IsEditing = true;
            SelectedProduct = product;

            ProductName = product.Name;
            Category = product.Category;
            PricePerKg = product.PricePerKg;
            QuantityInStock = product.QuantityInStock;
            DeliveryDate = product.DeliveryDate;
            ExpiryDate = product.ExpiryDate;
            Description = product.Description ?? string.Empty;
            IsAvailable = product.IsAvailable;
            UnitType = product.UnitType;
        }

        [RelayCommand]
        private async Task SaveProductAsync()
        {
            if (string.IsNullOrWhiteSpace(ProductName) || string.IsNullOrWhiteSpace(Category))
            {
                ErrorMessage = "Название и категория обязательны";
                return;
            }

            IsLoading = true;
            ErrorMessage = string.Empty;

            try
            {
                var productData = new Product
                {
                    Name = ProductName,
                    Category = Category,
                    PricePerKg = PricePerKg,
                    QuantityInStock = QuantityInStock,
                    DeliveryDate = DeliveryDate,
                    ExpiryDate = ExpiryDate,
                    Description = Description,
                    IsAvailable = IsAvailable,
                    UnitType = UnitType
                };

                Product? result;
                if (SelectedProduct != null)
                {
                    result = await _apiService.UpdateProductAsync(SelectedProduct.Id, productData);
                }
                else
                {
                    result = await _apiService.CreateProductAsync(productData);
                }

                if (result != null)
                {
                    if (SelectedProduct != null)
                    {
                        var index = Products.IndexOf(SelectedProduct);
                        if (index >= 0)
                        {
                            Products[index] = result;
                        }
                    }
                    else
                    {
                        Products.Add(result);
                    }

                    CancelEdit();
                }
                else
                {
                    ErrorMessage = "Ошибка сохранения товара";
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
        private void CancelEdit()
        {
            IsEditing = false;
            SelectedProduct = null;
            ClearForm();
        }

        [RelayCommand]
        private async Task DeleteProductAsync(Product? product)
        {
            if (product == null) return;

            try
            {
                var success = await _apiService.DeleteProductAsync(product.Id);
                if (success)
                {
                    Products.Remove(product);
                }
                else
                {
                    ErrorMessage = "Ошибка удаления товара";
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка: {ex.Message}";
            }
        }

        [RelayCommand]
        private void OpenProduct(Product? product)
        {
            if (product == null) return;
            
            Console.WriteLine($"👆 Opening product: {product.Name}");
            StartEdit(product);
        }

        private void ClearForm()
        {
            ProductName = string.Empty;
            Category = string.Empty;
            PricePerKg = 0;
            QuantityInStock = 0;
            DeliveryDate = null;
            ExpiryDate = null;
            Description = string.Empty;
            IsAvailable = true;
            UnitType = "kg";
        }
    }
}
