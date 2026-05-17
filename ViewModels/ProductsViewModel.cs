using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
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
        private ObservableCollection<Product> _filteredProducts = new();

        [ObservableProperty]
        private string _searchText = string.Empty;

        [ObservableProperty]
        private Product? _selectedProduct;

        // Bulk editing properties
        [ObservableProperty]
        private bool _isBulkEditing = false;

        [ObservableProperty]
        private string _bulkCategory = string.Empty;

        [ObservableProperty]
        private DateTime? _bulkExpiryDate;

        [ObservableProperty]
        private ObservableCollection<Product> _bulkEditCandidates = new();

        [ObservableProperty]
        private ObservableCollection<Product> _selectedProducts = new();

        [ObservableProperty]
        private int _bulkEditCount = 0;

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

        [ObservableProperty]
        private string? _pendingImagePath;

        [ObservableProperty]
        private string? _currentImageUrl;

        [ObservableProperty]
        private bool _isUploadingImage = false;

        partial void OnSelectedProductChanged(Product? value)
        {
            if (value != null)
            {
                LoadProductImageAsync(value);
            }
        }

        partial void OnSearchTextChanged(string value)
        {
            FilterProducts();
        }

        partial void OnSelectedProductsChanged(ObservableCollection<Product> value)
        {
            BulkEditCount = value?.Count ?? 0;
        }

        private void FilterProducts()
        {
            if (string.IsNullOrWhiteSpace(SearchText))
            {
                FilteredProducts = new ObservableCollection<Product>(Products);
            }
            else
            {
                var filtered = Products.Where(p => 
                    p.Name.Contains(SearchText, StringComparison.OrdinalIgnoreCase) ||
                    p.Category.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
                FilteredProducts = new ObservableCollection<Product>(filtered);
            }
            HasProducts = FilteredProducts.Count > 0;
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
                FilterProducts();
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
            PendingImagePath = null;
            CurrentImageUrl = product.ImageURL;
        }

        [RelayCommand]
        public void SetImagePath(string? path)
        {
            PendingImagePath = path;
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

                if (result != null && !string.IsNullOrEmpty(PendingImagePath))
                {
                    IsUploadingImage = true;
                    var uploaded = await _apiService.UploadProductImageAsync(result.Id, PendingImagePath);
                    IsUploadingImage = false;
                    if (uploaded.HasValue)
                    {
                        result.ImageURL = uploaded.Value.Url;
                        result.ImageHash = uploaded.Value.Hash;
                    }
                    else
                    {
                        ErrorMessage = "Товар сохранён, но изображение не удалось загрузить";
                    }
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

        [RelayCommand]
        private void StartBulkEdit()
        {
            IsBulkEditing = true;
            BulkCategory = string.Empty;
            BulkExpiryDate = null;
            BulkEditCandidates.Clear();
            SelectedProducts.Clear();
            ErrorMessage = string.Empty;
        }

        [RelayCommand]
        private void CancelBulkEdit()
        {
            IsBulkEditing = false;
            BulkCategory = string.Empty;
            BulkExpiryDate = null;
            BulkEditCandidates.Clear();
            SelectedProducts.Clear();
        }

        [RelayCommand]
        private void SearchBulkEditCandidates()
        {
            // Search products by name/category (only filter, no date filter)
            var query = Products.AsEnumerable();
            
            // Filter by category/name if specified
            if (!string.IsNullOrWhiteSpace(BulkCategory))
            {
                query = query.Where(p => 
                    p.Name.Contains(BulkCategory, StringComparison.OrdinalIgnoreCase) ||
                    p.Category.Contains(BulkCategory, StringComparison.OrdinalIgnoreCase));
            }
            
            BulkEditCandidates = new ObservableCollection<Product>(query);
            // Don't auto-select - let user choose
            SelectedProducts.Clear();
        }

        [RelayCommand]
        private void ToggleProductSelection(Product product)
        {
            if (SelectedProducts.Contains(product))
            {
                SelectedProducts.Remove(product);
            }
            else
            {
                SelectedProducts.Add(product);
            }
            BulkEditCount = SelectedProducts.Count;
        }

        [RelayCommand]
        private void SelectAllBulkCandidates()
        {
            SelectedProducts = new ObservableCollection<Product>(BulkEditCandidates);
            BulkEditCount = SelectedProducts.Count;
        }

        [RelayCommand]
        private void DeselectAllBulkCandidates()
        {
            SelectedProducts.Clear();
            BulkEditCount = 0;
        }

        [RelayCommand]
        private async Task ApplyBulkEditAsync()
        {
            if (!BulkExpiryDate.HasValue)
            {
                ErrorMessage = "Укажите новый срок годности";
                return;
            }

            var productsToEdit = SelectedProducts.ToList();
                
            if (productsToEdit.Count == 0)
            {
                ErrorMessage = "Выберите хотя бы один товар для редактирования";
                return;
            }

            IsLoading = true;
            ErrorMessage = string.Empty;
            int successCount = 0;
            int failCount = 0;

            try
            {
                foreach (var product in productsToEdit)
                {
                    var updatedProduct = new Product
                    {
                        Name = product.Name,
                        Category = product.Category,
                        PricePerKg = product.PricePerKg,
                        QuantityInStock = product.QuantityInStock,
                        DeliveryDate = product.DeliveryDate,
                        ExpiryDate = BulkExpiryDate,
                        Description = product.Description,
                        IsAvailable = product.IsAvailable,
                        UnitType = product.UnitType
                    };

                    var result = await _apiService.UpdateProductAsync(product.Id, updatedProduct);
                    if (result != null)
                    {
                        successCount++;
                        // Update in memory
                        var index = Products.IndexOf(product);
                        if (index >= 0)
                        {
                            Products[index] = result;
                        }
                    }
                    else
                    {
                        failCount++;
                    }
                }

                FilterProducts();
                
                if (failCount == 0)
                {
                    ErrorMessage = $"✅ Успешно обновлено {successCount} товаров";
                    CancelBulkEdit();
                }
                else
                {
                    ErrorMessage = $"✅ Обновлено: {successCount}, ❌ Ошибок: {failCount}";
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка массового редактирования: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
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
            PendingImagePath = null;
            CurrentImageUrl = null;
        }
    }
}
