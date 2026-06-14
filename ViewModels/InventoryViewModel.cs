using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Avalonia.Platform.Storage;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace AvaloniaApplication1.ViewModels
{
    /// <summary>
    /// ViewModel for inventory management (matches iOS InventoryView)
    /// </summary>
    public partial class InventoryViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;
        private readonly User _currentUser;
        
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
        
        [ObservableProperty]
        private bool _showStatistics = false;
        
        [ObservableProperty]
        private decimal _totalShortageValue;
        
        [ObservableProperty]
        private decimal _totalSurplusValue;
        
        [ObservableProperty]
        private decimal _totalDifferenceValue;
        
        [ObservableProperty]
        private ObservableCollection<InventoryDifferenceItem> _differenceItems = new();
        
        [ObservableProperty]
        private ObservableCollection<InventoryDifferenceItem> _shortageItems = new();
        
        [ObservableProperty]
        private ObservableCollection<InventoryDifferenceItem> _surplusItems = new();
        
        public bool HasShortages => ShortagesCount > 0;
        public bool HasSurpluses => SurplusesCount > 0;
        public bool HasOnlySurpluses => HasSurpluses && !HasShortages;
        public bool ShowShortageWarning => HasShortages;
        public bool ShowSuccess => !HasShortages && !HasSurpluses;
        
        public InventoryViewModel(User currentUser)
        {
            _currentUser = currentUser;
            _apiService = new ApiService(currentUser.Token, currentUser.SessionKey);
            // Auto-load products on initialization (like mobile app)
            _ = InitializeAsync();
        }
        
        private async Task InitializeAsync()
        {
            await LoadProductsAsync();
        }
        
        [RelayCommand]
        private async Task LoadProductsAsync()
        {
            if (IsProcessing) return;
            
            Console.WriteLine("📋 Loading products for inventory...");
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
                        UnitType = product.UnitType,
                        PricePerKg = product.PricePerKg
                    });
                }
                
                UpdateCounts();
                FilterItems();
                OnPropertyChanged(nameof(HasInventoryStarted));
                
                Console.WriteLine($"✅ Loaded {InventoryItems.Count} items for inventory");
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка: {ex.Message}";
                Console.WriteLine($"❌ Load products error: {ex.Message}");
            }
            finally
            {
                IsProcessing = false;
            }
        }
        
        partial void OnSelectedFilterChanged(string value)
        {
            FilterItems();
        }
        
        public bool HasInventoryStarted => InventoryItems.Count > 0;
        
        [RelayCommand]
        private async Task StartInventoryAsync()
        {
            // Products already loaded on initialization
            // This button now just refreshes the list
            await LoadProductsAsync();
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
        private void CloseStatistics()
        {
            ShowStatistics = false;
            InventoryItems.Clear();
            FilteredItems.Clear();
            OnPropertyChanged(nameof(HasInventoryStarted));
        }
        
        [RelayCommand]
        private async Task FinishInventoryAsync()
        {
            Console.WriteLine("✓ Finishing inventory...");
            IsProcessing = true;
            ErrorMessage = string.Empty;

            try
            {
                // Recalculate counts from current edited values before proceeding
                UpdateCounts();

                var hasDifferences = InventoryItems.Any(x => Math.Abs(x.Difference) > 0.01m);
                var failedUpdates = new System.Collections.Generic.List<string>();

                if (hasDifferences)
                {
                    Console.WriteLine("⚠️ There are differences, updating products on server...");

                    // Update each product individually on the server (matching iOS approach)
                    foreach (var item in InventoryItems.Where(x => Math.Abs(x.Difference) > 0.01m))
                    {
                        var success = await _apiService.UpdateProductQuantityAsync(item.ProductId, item.ActualQuantity);
                        if (!success)
                        {
                            failedUpdates.Add(item.ProductName);
                            Console.WriteLine($"❌ Failed to update '{item.ProductName}' quantity");
                        }
                    }

                    if (failedUpdates.Count > 0)
                    {
                        ErrorMessage = $"Не удалось обновить: {string.Join(", ", failedUpdates)}";
                    }
                    else
                    {
                        Console.WriteLine("✅ All product quantities updated successfully");
                    }
                }
                else
                {
                    Console.WriteLine("ℹ️ No adjustments needed");
                }

                // Always calculate and show statistics (like iOS does)
                CalculateStatistics();
                ShowStatistics = true;
                OnPropertyChanged(nameof(HasInventoryStarted));
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

        [RelayCommand]
        private async Task ExportReportAsync()
        {
            try
            {
                var dateStr = DateTime.Now.ToString("dd.MM.yyyy");
                var fileName = $"Инвентаризация_{DateTime.Now:dd-MM-yyyy}.pdf";

                // Show save file dialog
                var storage = App.StorageProvider;
                if (storage == null)
                {
                    ErrorMessage = "Не удалось открыть диалог сохранения";
                    return;
                }

                var file = await storage.SaveFilePickerAsync(new FilePickerSaveOptions
                {
                    Title = "Сохранить отчет инвентаризации",
                    SuggestedFileName = fileName,
                    DefaultExtension = "pdf",
                    FileTypeChoices = new[]
                    {
                        new FilePickerFileType("PDF документ")
                        {
                            Patterns = new[] { "*.pdf" }
                        }
                    }
                });

                if (file == null)
                {
                    Console.WriteLine("📄 Save cancelled by user");
                    return;
                }

                var savePath = file.Path.LocalPath;
                GenerateReportPdf(savePath, dateStr);

                Console.WriteLine($"📄 PDF report saved to: {savePath}");

                // Open the PDF with default app
                Process.Start(new ProcessStartInfo
                {
                    FileName = savePath,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка экспорта PDF: {ex.Message}";
                Console.WriteLine($"❌ PDF export error: {ex.Message}");
            }
        }

        private void GenerateReportPdf(string filePath, string reportDate)
        {
            QuestPDF.Settings.License = LicenseType.Community;

            var differences = InventoryItems
                .Where(x => Math.Abs(x.Difference) > 0.01m)
                .ToList();

            var shortageItems = differences.Where(x => x.Difference < 0).ToList();
            var surplusItems = differences.Where(x => x.Difference > 0).ToList();
            var totalShortageValue = shortageItems.Sum(x => Math.Abs(x.Difference) * x.PricePerKg);
            var totalSurplusValue = surplusItems.Sum(x => x.Difference * x.PricePerKg);

            Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4);
                    page.Margin(30);
                    page.DefaultTextStyle(x => x.FontSize(11).FontFamily("Arial"));

                    page.Header().Column(header =>
                    {
                        header.Item().Text($"Инвентаризация за {reportDate} г.")
                            .FontSize(18).Bold();
                        header.Item().Text($"Ответственный: {_currentUser.FullName}")
                            .FontSize(10).FontColor(Colors.Grey.Medium);
                    });

                    page.Content().Column(col =>
                    {
                        col.Spacing(15);

                        // Summary cards row 1
                        col.Item().Row(row =>
                        {
                            row.RelativeItem().Border(1).BorderColor(Colors.Blue.Medium).Background(Colors.Blue.Lighten4).Padding(10)
                                .Column(c =>
                                {
                                    c.Item().Text("Всего товаров").FontSize(9).FontColor(Colors.Grey.Medium);
                                    c.Item().Text(InventoryItems.Count.ToString()).FontSize(16).Bold();
                                });
                            row.RelativeItem().Border(1).BorderColor(Colors.Green.Medium).Background(Colors.Green.Lighten4).Padding(10)
                                .Column(c =>
                                {
                                    c.Item().Text("В норме").FontSize(9).FontColor(Colors.Grey.Medium);
                                    c.Item().Text(NormalCount.ToString()).FontSize(16).Bold();
                                });
                        });

                        // Summary cards row 2
                        col.Item().Row(row =>
                        {
                            row.RelativeItem().Border(1).BorderColor(Colors.Red.Medium).Background(Colors.Red.Lighten4).Padding(10)
                                .Column(c =>
                                {
                                    c.Item().Text("Недостачи").FontSize(9).FontColor(Colors.Grey.Medium);
                                    c.Item().Text(ShortagesCount.ToString()).FontSize(16).Bold().FontColor(Colors.Red.Medium);
                                });
                            row.RelativeItem().Border(1).BorderColor(Colors.Green.Medium).Background(Colors.Green.Lighten4).Padding(10)
                                .Column(c =>
                                {
                                    c.Item().Text("Излишки").FontSize(9).FontColor(Colors.Grey.Medium);
                                    c.Item().Text(SurplusesCount.ToString()).FontSize(16).Bold().FontColor(Colors.Green.Medium);
                                });
                        });

                        // Financial summary
                        if (shortageItems.Any() || surplusItems.Any())
                        {
                            col.Item().Border(1).BorderColor(Colors.Grey.Medium).Background(Colors.Grey.Lighten4).Padding(12)
                                .Column(c =>
                                {
                                    if (shortageItems.Any())
                                        c.Item().Row(r =>
                                        {
                                            r.RelativeItem().Text("Сумма недостач:");
                                            r.ConstantItem(120).AlignRight().Text($"-{totalShortageValue:F0} ₽").Bold().FontColor(Colors.Red.Medium);
                                        });
                                    if (surplusItems.Any())
                                        c.Item().Row(r =>
                                        {
                                            r.RelativeItem().Text("Сумма излишков:");
                                            r.ConstantItem(120).AlignRight().Text($"+{totalSurplusValue:F0} ₽").Bold().FontColor(Colors.Green.Medium);
                                        });
                                });
                        }

                        // Shortages section
                        if (shortageItems.Any())
                        {
                            col.Item().PaddingTop(10).Text("Недостачи").FontSize(14).Bold().FontColor(Colors.Red.Medium);
                            col.Item().Table(table =>
                            {
                                table.ColumnsDefinition(columns =>
                                {
                                    columns.RelativeColumn(3);
                                    columns.ConstantColumn(80);
                                    columns.ConstantColumn(80);
                                    columns.ConstantColumn(80);
                                    columns.ConstantColumn(80);
                                });
                                table.Header(header =>
                                {
                                    header.Cell().Text("Товар").Bold();
                                    header.Cell().AlignCenter().Text("Система").Bold();
                                    header.Cell().AlignCenter().Text("Факт").Bold();
                                    header.Cell().AlignCenter().Text("Разница").Bold();
                                    header.Cell().AlignRight().Text("Сумма").Bold();
                                });
                                foreach (var item in shortageItems)
                                {
                                    var unit = item.UnitType == "piece" ? "шт" : "кг";
                                    var diffVal = Math.Abs(item.Difference) * item.PricePerKg;
                                    table.Cell().Text(item.ProductName);
                                    table.Cell().AlignCenter().Text($"{item.SystemQuantity:F2} {unit}");
                                    table.Cell().AlignCenter().Text($"{item.ActualQuantity:F2} {unit}");
                                    table.Cell().AlignCenter().Text($"{item.Difference:F2} {unit}").FontColor(Colors.Red.Medium);
                                    table.Cell().AlignRight().Text($"{diffVal:F2} ₽");
                                }
                            });
                        }

                        // Surpluses section
                        if (surplusItems.Any())
                        {
                            col.Item().PaddingTop(10).Text("Излишки").FontSize(14).Bold().FontColor(Colors.Green.Medium);
                            col.Item().Table(table =>
                            {
                                table.ColumnsDefinition(columns =>
                                {
                                    columns.RelativeColumn(3);
                                    columns.ConstantColumn(80);
                                    columns.ConstantColumn(80);
                                    columns.ConstantColumn(80);
                                    columns.ConstantColumn(80);
                                });
                                table.Header(header =>
                                {
                                    header.Cell().Text("Товар").Bold();
                                    header.Cell().AlignCenter().Text("Система").Bold();
                                    header.Cell().AlignCenter().Text("Факт").Bold();
                                    header.Cell().AlignCenter().Text("Разница").Bold();
                                    header.Cell().AlignRight().Text("Сумма").Bold();
                                });
                                foreach (var item in surplusItems)
                                {
                                    var unit = item.UnitType == "piece" ? "шт" : "кг";
                                    var diffVal = Math.Abs(item.Difference) * item.PricePerKg;
                                    table.Cell().Text(item.ProductName);
                                    table.Cell().AlignCenter().Text($"{item.SystemQuantity:F2} {unit}");
                                    table.Cell().AlignCenter().Text($"{item.ActualQuantity:F2} {unit}");
                                    table.Cell().AlignCenter().Text($"+{item.Difference:F2} {unit}").FontColor(Colors.Green.Medium);
                                    table.Cell().AlignRight().Text($"{diffVal:F2} ₽");
                                }
                            });
                        }

                        // Final status
                        if (!differences.Any())
                        {
                            col.Item().PaddingTop(20).AlignCenter().Text("Всё в порядке!").FontSize(16).Bold().FontColor(Colors.Green.Medium);
                            col.Item().AlignCenter().Text("Расхождений не обнаружено. Все товары соответствуют учетным данным.").FontSize(11).FontColor(Colors.Grey.Medium);
                        }
                        else if (!shortageItems.Any() && surplusItems.Any())
                        {
                            col.Item().PaddingTop(20).AlignCenter().Text("Что-то не так!").FontSize(16).Bold().FontColor(Colors.Orange.Medium);
                            col.Item().AlignCenter().Text($"Инвентаризация закрыта с расхождением. Обнаружен излишек товара ({surplusItems.Count} поз.).").FontSize(11).FontColor(Colors.Grey.Medium);
                        }
                        else if (shortageItems.Any())
                        {
                            col.Item().PaddingTop(20).AlignCenter().Text("Что-то не так!").FontSize(16).Bold().FontColor(Colors.Red.Medium);
                            col.Item().AlignCenter().Text($"Инвентаризация закрыта с расхождением. Недостача: {shortageItems.Count} поз., Излишек: {surplusItems.Count} поз.").FontSize(11).FontColor(Colors.Grey.Medium);
                        }
                    });
                });
            })
            .GeneratePdf(filePath);
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
        
        private void CalculateStatistics()
        {
            // Recalculate counts to reflect current edited values
            UpdateCounts();

            var differences = InventoryItems
                .Where(x => Math.Abs(x.Difference) > 0.01m)
                .ToList();
            
            TotalShortageValue = differences
                .Where(x => x.Difference < 0)
                .Sum(x => Math.Abs(x.Difference) * x.PricePerKg);
            
            TotalSurplusValue = differences
                .Where(x => x.Difference > 0)
                .Sum(x => x.Difference * x.PricePerKg);
            
            TotalDifferenceValue = TotalSurplusValue - TotalShortageValue;
            
            DifferenceItems.Clear();
            ShortageItems.Clear();
            SurplusItems.Clear();
            
            foreach (var item in differences.OrderBy(x => x.AdjustmentType).ThenBy(x => x.ProductName))
            {
                var diffItem = new InventoryDifferenceItem
                {
                    ProductName = item.ProductName,
                    Category = item.Category,
                    SystemQuantity = item.SystemQuantity,
                    ActualQuantity = item.ActualQuantity,
                    Difference = item.Difference,
                    UnitType = item.UnitType,
                    PricePerKg = item.PricePerKg,
                    DifferenceValue = Math.Abs(item.Difference) * item.PricePerKg,
                    AdjustmentType = item.AdjustmentType
                };
                
                DifferenceItems.Add(diffItem);
                
                if (item.AdjustmentType == AdjustmentType.Shortage)
                    ShortageItems.Add(diffItem);
                else if (item.AdjustmentType == AdjustmentType.Surplus)
                    SurplusItems.Add(diffItem);
            }
            
            // Notify dependent properties
            OnPropertyChanged(nameof(HasShortages));
            OnPropertyChanged(nameof(HasSurpluses));
            OnPropertyChanged(nameof(HasOnlySurpluses));
            OnPropertyChanged(nameof(ShowShortageWarning));
            OnPropertyChanged(nameof(ShowSuccess));
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
        private decimal _pricePerKg;
        
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
                return $"{sign}{Difference:F3} {UnitDisplay}";
            }
        }
        
        public string DisplayAdjustmentType
        {
            get
            {
                return AdjustmentType switch
                {
                    AdjustmentType.Shortage => "Недостача",
                    AdjustmentType.Surplus => "Излишек",
                    AdjustmentType.Normal => "В норме",
                    _ => "В норме"
                };
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
            OnPropertyChanged(nameof(DisplayAdjustmentType));
        }
    }
    
    public partial class InventoryStatisticsViewModel : ObservableObject
    {
        [ObservableProperty]
        private int _totalItems;
        
        [ObservableProperty]
        private int _shortagesCount;
        
        [ObservableProperty]
        private int _surplusesCount;
        
        [ObservableProperty]
        private decimal _totalShortageAmount;
        
        [ObservableProperty]
        private decimal _totalSurplusAmount;
    }
    
    /// <summary>
    /// Item with difference for statistics display
    /// </summary>
    public class InventoryDifferenceItem
    {
        public string ProductName { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public decimal SystemQuantity { get; set; }
        public decimal ActualQuantity { get; set; }
        public decimal Difference { get; set; }
        public string UnitType { get; set; } = "kg";
        public decimal PricePerKg { get; set; }
        public decimal DifferenceValue { get; set; }
        public AdjustmentType AdjustmentType { get; set; }
        
        public string UnitDisplay => UnitType == "piece" ? "шт" : "кг";
        public string DisplayDifference => $"{(Difference >= 0 ? "+" : "")}{Difference:F3} {UnitDisplay}";
        public string DisplayValue => $"{DifferenceValue:F2} ₽";
        public string DisplayType => AdjustmentType switch
        {
            AdjustmentType.Shortage => "Недостача",
            AdjustmentType.Surplus => "Излишек",
            _ => "В норме"
        };
        public string TypeColor => AdjustmentType switch
        {
            AdjustmentType.Shortage => "#DC2626",
            AdjustmentType.Surplus => "#16A34A",
            _ => "#6B7280"
        };
    }
}
