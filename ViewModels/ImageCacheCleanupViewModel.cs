using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Input;
using Avalonia.Media.Imaging;
using AvaloniaApplication1.Helpers;
using AvaloniaApplication1.Models;
using AvaloniaApplication1.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AvaloniaApplication1.ViewModels
{
    /// <summary>
    /// ViewModel for image cache cleanup functionality
    /// </summary>
    public partial class ImageCacheCleanupViewModel : ViewModelBase
    {
        private readonly ApiService _apiService;

        [ObservableProperty]
        private ObservableCollection<UnusedCachedFileViewModel> _unusedFiles = new();

        [ObservableProperty]
        private bool _isLoading;

        [ObservableProperty]
        private string? _errorMessage;

        public ImageCacheCleanupViewModel()
        {
            _apiService = new ApiService();
            RefreshCommand = new AsyncRelayCommand(LoadUnusedFilesAsync);
            DeleteSelectedCommand = new AsyncRelayCommand(DeleteSelectedFilesAsync);
            SelectAllCommand = new RelayCommand(SelectAll);
            ViewImageCommand = new RelayCommand<UnusedCachedFileViewModel>(ViewImage);
        }

        public ICommand RefreshCommand { get; }
        public ICommand DeleteSelectedCommand { get; }
        public ICommand SelectAllCommand { get; }
        public ICommand ViewImageCommand { get; }

        public bool HasError => !string.IsNullOrEmpty(ErrorMessage);
        public bool HasUnusedFiles => UnusedFiles.Count > 0;
        public bool HasSelectedFiles => UnusedFiles.Any(f => f.IsSelected);
        public bool ShowEmptyState => !IsLoading && !HasError && !HasUnusedFiles;

        public string TotalSizeFormatted
        {
            get
            {
                var totalBytes = UnusedFiles.Sum(f => f.Size);
                return FormatBytes(totalBytes);
            }
        }

        public string SelectedCountText
        {
            get
            {
                var selected = UnusedFiles.Count(f => f.IsSelected);
                return $"Выбрано: {selected} из {UnusedFiles.Count}";
            }
        }

        public string DeleteButtonText
        {
            get
            {
                var selected = UnusedFiles.Count(f => f.IsSelected);
                return selected > 0 ? $"Удалить ({selected})" : "Удалить";
            }
        }

        public async Task LoadUnusedFilesAsync()
        {
            IsLoading = true;
            ErrorMessage = null;

            try
            {
                // Fetch all products to get their image hashes
                var products = await _apiService.GetProductsAsync();
                var productHashes = products
                    .Where(p => !string.IsNullOrEmpty(p.ImageHash))
                    .Select(p => p.ImageHash!)
                    .ToList();

                Console.WriteLine($"📦 Products with images: {productHashes.Count}");

                // Find unused cached images
                var unusedFiles = ImageCacheManager.Instance.FindUnusedCachedImages(productHashes);
                Console.WriteLine($"🗑️ Unused cached files: {unusedFiles.Count}");

                // Convert to view models
                var viewModels = unusedFiles.Select(f => new UnusedCachedFileViewModel
                {
                    FileName = f.FileName,
                    FilePath = f.FilePath,
                    DisplayName = ImageCacheManager.Instance.GetDisplayName(f),
                    OriginalFileName = f.OriginalUrl != null 
                        ? Path.GetFileName(new Uri(f.OriginalUrl).LocalPath) 
                        : f.FileName,
                    Size = f.Size,
                    SizeFormatted = f.SizeFormatted,
                    LastModified = f.LastModified,
                    Thumbnail = LoadThumbnail(f.FilePath),
                    HasThumbnail = File.Exists(f.FilePath)
                }).ToList();

                UnusedFiles = new ObservableCollection<UnusedCachedFileViewModel>(viewModels);
                OnPropertyChanged(nameof(ShowEmptyState));

                // Subscribe to property changes for selection tracking
                foreach (var vm in UnusedFiles)
                {
                    vm.PropertyChanged += (s, e) =>
                    {
                        if (e.PropertyName == nameof(UnusedCachedFileViewModel.IsSelected))
                        {
                            OnPropertyChanged(nameof(HasSelectedFiles));
                            OnPropertyChanged(nameof(SelectedCountText));
                            OnPropertyChanged(nameof(DeleteButtonText));
                        }
                    };
                }
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка загрузки: {ex.Message}";
                OnPropertyChanged(nameof(ShowEmptyState));
                Console.WriteLine($"❌ Error loading unused files: {ex}");
            }
            finally
            {
                IsLoading = false;
                OnPropertyChanged(nameof(ShowEmptyState));
            }
        }

        private Bitmap? LoadThumbnail(string path)
        {
            try
            {
                if (File.Exists(path))
                {
                    // Load small thumbnail
                    using var stream = File.OpenRead(path);
                    return new Bitmap(stream);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Failed to load thumbnail: {ex.Message}");
            }
            return null;
        }

        private async Task DeleteSelectedFilesAsync()
        {
            var selectedFiles = UnusedFiles.Where(f => f.IsSelected).ToList();
            if (!selectedFiles.Any()) return;

            try
            {
                var pathsToDelete = selectedFiles.Select(f => f.FilePath).ToList();
                var deletedCount = ImageCacheManager.Instance.DeleteCachedFiles(pathsToDelete);

                Console.WriteLine($"🗑️ Deleted {deletedCount} files");

                // Remove from list
                foreach (var file in selectedFiles)
                {
                    UnusedFiles.Remove(file);
                }

                // Notify property changes
                OnPropertyChanged(nameof(HasUnusedFiles));
                OnPropertyChanged(nameof(TotalSizeFormatted));
                OnPropertyChanged(nameof(HasSelectedFiles));
                OnPropertyChanged(nameof(SelectedCountText));
                OnPropertyChanged(nameof(DeleteButtonText));
            }
            catch (Exception ex)
            {
                ErrorMessage = $"Ошибка удаления: {ex.Message}";
                Console.WriteLine($"❌ Error deleting files: {ex}");
            }
        }

        private void SelectAll()
        {
            bool allSelected = UnusedFiles.All(f => f.IsSelected);
            foreach (var file in UnusedFiles)
            {
                file.IsSelected = !allSelected;
            }
        }

        private void ViewImage(UnusedCachedFileViewModel? file)
        {
            if (file == null) return;

            try
            {
                if (File.Exists(file.FilePath))
                {
                    // Open image in default viewer
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = file.FilePath,
                        UseShellExecute = true
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Failed to open image: {ex.Message}");
            }
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes == 0) return "0 B";
            string[] sizes = { "B", "KB", "MB", "GB" };
            int i = (int)Math.Floor(Math.Log(bytes, 1024));
            i = Math.Min(i, sizes.Length - 1);
            return $"{bytes / Math.Pow(1024, i):F2} {sizes[i]}";
        }
    }

    /// <summary>
    /// ViewModel for a single unused cached file
    /// </summary>
    public partial class UnusedCachedFileViewModel : ObservableObject
    {
        [ObservableProperty]
        private string _fileName = "";

        [ObservableProperty]
        private string _filePath = "";

        [ObservableProperty]
        private string _displayName = "";

        [ObservableProperty]
        private string _originalFileName = "";

        [ObservableProperty]
        private long _size;

        [ObservableProperty]
        private string _sizeFormatted = "";

        [ObservableProperty]
        private DateTime _lastModified;

        [ObservableProperty]
        private Bitmap? _thumbnail;

        [ObservableProperty]
        private bool _hasThumbnail;

        [ObservableProperty]
        private bool _isSelected;
    }
}
