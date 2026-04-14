using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    /// <summary>
    /// ViewModel for inventory management (matches iOS InventoryView)
    /// </summary>
    public partial class InventoryViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        
        [ObservableProperty]
        private ObservableCollection<InventoryItemViewModel> _inventoryItems = new();
        
        [ObservableProperty]
        private ObservableCollection<InventoryItemViewModel> _filteredItems = new();
        
        [ObservableProperty]
        private string _selectedFilter = "Все";
        
        [ObservableProperty]
        private bool _isProcessing = false;
        
        [ObservableProperty]
        private string _errorMessage = string.Empty;
        
        [ObservableProperty]
        private int _totalCount;
        
        [ObservableProperty]
        private int _shortagesCount;
        
        [ObservableProperty]
        private int _surplusesCount;
        
        [ObservableProperty]
        private int _normalCount;
        
        public InventoryViewModel()
        {
            _apiService = new ApiService();
        }
        
        partial void OnSelectedFilterChanged(string value)
        {
            FilterItems();
        }
        
        public bool HasInventoryStarted => InventoryItems.Count > 0;
        
        [RelayCommand]
        private async Task StartInventoryAsync()
        {
            Console.WriteLine("📋 Starting inventory...");
            IsProcessing = true;
            ErrorMessage = string.Empty;
            
            try
            {
                var products = await _apiService.GetProductsAsync();
                
                InventoryItems.Clear();
                foreach (var product in products)
                {
                    InventoryItems.Add(new InventoryItemViewModel
                    {
                        ProductId = product.Id,
                        ProductName = product.Name,
                        Category = product.Category,
                        SystemQuantity = product.QuantityInStock,
                        ActualQuantity = product.QuantityInStock,
                        UnitType = product.UnitType
                    });
                }
                
                UpdateCounts();
                FilterItems();
                
                Console.WriteLine($"✅ Loaded {InventoryItems.Count} items for inventory");
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка: {ex.Message}";
                Console.WriteLine($"❌ Start inventory error: {ex.Message}");
            }
            finally
            {
                IsProcessing = false;
            }
        }
        
        [RelayCommand]
        private void CancelInventory()
        {
            Console.WriteLine("🗑 Cancelling inventory");
            InventoryItems.Clear();
            FilteredItems.Clear();
            OnPropertyChanged(nameof(HasInventoryStarted));
        }
        
        [RelayCommand]
        private void SetSelectedFilter(string filter)
        {
            SelectedFilter = filter;
        }
        
        [RelayCommand]
        private async Task FinishInventoryAsync()
        {
            Console.WriteLine("✓ Finishing inventory...");
            IsProcessing = true;
            ErrorMessage = string.Empty;
            
            try
            {
                // Check if there are differences
                var hasDifferences = InventoryItems.Any(x => Math.Abs(x.Difference) > 0.01m);
                
                if (hasDifferences)
                {
                    // In real implementation, show confirmation dialog
                    Console.WriteLine("⚠️ There are differences, applying adjustments...");
                }
                
                // Apply changes
                var adjustmentRequest = new InventoryAdjustmentRequest
                {
                    Items = InventoryItems
                        .Where(x => Math.Abs(x.Difference) > 0.01m)
                        .Select(x => new InventoryAdjustmentItem
                        {
                            ProductId = x.ProductId,
                            ActualQuantity = x.ActualQuantity,
                            Comment = x.Difference > 0 ? "Surplus found" : "Shortage found"
                        })
                        .ToList()
                };
                
                if (adjustmentRequest.Items.Any())
                {
                    var success = await _apiService.ApplyInventoryAdjustmentAsync(adjustmentRequest);
                    if (success)
                    {
                        Console.WriteLine("✅ Inventory adjustments applied successfully");
                    }
                    else
                    {
                        ErrorMessage = "Failed to apply adjustments";
                    }
                }
                else
                {
                    Console.WriteLine("ℹ️ No adjustments needed");
                }
                
                // Clear after finishing
                InventoryItems.Clear();
                FilteredItems.Clear();
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка: {ex.Message}";
                Console.WriteLine($"❌ Finish inventory error: {ex.Message}");
            }
            finally
            {
                IsProcessing = false;
            }
        }
        
        private void FilterItems()
        {
            Console.WriteLine($"🔄 FilterItems called. InventoryItems.Count={InventoryItems.Count}, SelectedFilter={SelectedFilter}");
            
            FilteredItems.Clear();
            
            foreach (var item in InventoryItems)
            {
                var matchesFilter = SelectedFilter switch
                {
                    "Все" => true,
                    "Недостачи" => item.AdjustmentType == AdjustmentType.Shortage,
                    "Излишки" => item.AdjustmentType == AdjustmentType.Surplus,
                    "В норме" => item.AdjustmentType == AdjustmentType.Normal,
                    _ => true
                };
                
                if (matchesFilter)
                {
                    FilteredItems.Add(item);
                }
            }
            
            // Force UI refresh by raising property changed
            OnPropertyChanged(nameof(FilteredItems));
            
            Console.WriteLine($"✅ FilterItems complete. FilteredItems.Count={FilteredItems.Count}");
            Console.WriteLine($"🔍 Filter: {SelectedFilter}, Showing {FilteredItems.Count} of {InventoryItems.Count}");
        }
        
        private void UpdateCounts()
        {
            TotalCount = InventoryItems.Count;
            ShortagesCount = InventoryItems.Count(x => x.AdjustmentType == AdjustmentType.Shortage);
            SurplusesCount = InventoryItems.Count(x => x.AdjustmentType == AdjustmentType.Surplus);
            NormalCount = InventoryItems.Count(x => x.AdjustmentType == AdjustmentType.Normal);
        }
        
        partial void OnInventoryItemsChanged(ObservableCollection<InventoryItemViewModel> value)
        {
            UpdateCounts();
            FilterItems();
            OnPropertyChanged(nameof(HasInventoryStarted));
        }
    }
    
    /// <summary>
    /// View model for single inventory item (extends InventoryItem with UI properties)
    /// </summary>
    public partial class InventoryItemViewModel : ObservableObject
    {
        [ObservableProperty]
        private string _productId = string.Empty;
        
        [ObservableProperty]
        private string _productName = string.Empty;
        
        [ObservableProperty]
        private string _category = string.Empty;
        
        [ObservableProperty]
        private decimal _systemQuantity;
        
        [ObservableProperty]
        private decimal _actualQuantity;
        
        [ObservableProperty]
        private string _unitType = "kg";
        
        [ObservableProperty]
        private bool _isEditing = false;
        
        public decimal Difference => ActualQuantity - SystemQuantity;
        
        public AdjustmentType AdjustmentType
        {
            get
            {
                if (Difference < -0.01m) return AdjustmentType.Shortage;
                if (Difference > 0.01m) return AdjustmentType.Surplus;
                return AdjustmentType.Normal;
            }
        }
        
        public string DisplayDifference
        {
            get
            {
                var sign = Difference >= 0 ? "+" : "";
                return $"{sign}{Difference:F2} {UnitType}";
            }
        }
        
        public string DifferenceColor
        {
            get
            {
                return AdjustmentType switch
                {
                    AdjustmentType.Shortage => "#DC2626", // Red
                    AdjustmentType.Surplus => "#16A34A",  // Green
                    AdjustmentType.Normal => "#6B7280",   // Gray
                    _ => "#6B7280"                         // Default
                };
            }
        }
        
        partial void OnActualQuantityChanged(decimal value)
        {
            OnPropertyChanged(nameof(Difference));
            OnPropertyChanged(nameof(DisplayDifference));
            OnPropertyChanged(nameof(DifferenceColor));
            OnPropertyChanged(nameof(AdjustmentType));
        }
    }
}
