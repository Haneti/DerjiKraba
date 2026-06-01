using System;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using AvaloniaApplication1.Helpers;
using AvaloniaApplication1.Models;

namespace AvaloniaApplication1.Controls
{
    /// <summary>
    /// Image control with automatic caching and hash verification
    /// </summary>
    public class CachedImage : Image
    {
        private CancellationTokenSource? _loadingCts;

        public static readonly StyledProperty<string?> SourceUrlProperty =
            AvaloniaProperty.Register<CachedImage, string?>(
                nameof(SourceUrl));

        public static readonly StyledProperty<string?> ImageHashProperty =
            AvaloniaProperty.Register<CachedImage, string?>(
                nameof(ImageHash));

        public static readonly StyledProperty<string?> ProductNameProperty =
            AvaloniaProperty.Register<CachedImage, string?>(
                nameof(ProductName));

        static CachedImage()
        {
            SourceUrlProperty.Changed.AddClassHandler<CachedImage>(async (x, e) => await x.LoadImageAsync());
            ImageHashProperty.Changed.AddClassHandler<CachedImage>(async (x, e) => await x.LoadImageAsync());
            ProductNameProperty.Changed.AddClassHandler<CachedImage>(async (x, e) => await x.LoadImageAsync());
        }

        public string? SourceUrl
        {
            get => GetValue(SourceUrlProperty);
            set => SetValue(SourceUrlProperty, value);
        }

        public string? ImageHash
        {
            get => GetValue(ImageHashProperty);
            set => SetValue(ImageHashProperty, value);
        }

        public string? ProductName
        {
            get => GetValue(ProductNameProperty);
            set => SetValue(ProductNameProperty, value);
        }

        private async Task LoadImageAsync()
        {
            // Cancel any previous loading operation
            _loadingCts?.Cancel();
            _loadingCts = new CancellationTokenSource();
            var token = _loadingCts.Token;
            
            try
            {
                if (string.IsNullOrEmpty(SourceUrl))
                {
                    // Show placeholder if no URL
                    Source = GeneratePlaceholderForProduct(ProductName);
                    return;
                }

                // First show placeholder
                Source = GeneratePlaceholderForProduct(ProductName);
                
                // Check if cancelled
                token.ThrowIfCancellationRequested();

                // Then load from cache asynchronously (heavy work already offloaded inside GetImageAsync)
                var bitmap = await ImageCacheManager.Instance.GetImageAsync(SourceUrl, ImageHash);
                
                // Check if this is still the current request and not cancelled
                if (!token.IsCancellationRequested && bitmap != null)
                {
                    Source = bitmap;
                }
            }
            catch (OperationCanceledException)
            {
                // Loading was cancelled, ignore
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Failed to load image: {ex.Message}");
                if (!token.IsCancellationRequested)
                {
                    Source = GeneratePlaceholderForProduct(ProductName);
                }
            }
        }
        
        protected override Size MeasureOverride(Size availableSize)
        {
            // Protect against null Source
            if (Source == null)
            {
                // Return default size if no source
                return new Size(200, 160);
            }
            
            try
            {
                return base.MeasureOverride(availableSize);
            }
            catch
            {
                // If measurement fails (e.g., bitmap issue), return fallback size
                return new Size(200, 160);
            }
        }

        protected override Size ArrangeOverride(Size finalSize)
        {
            // Protect against corrupted bitmaps that throw on Size access
            if (Source == null)
            {
                return base.ArrangeOverride(finalSize);
            }

            try
            {
                return base.ArrangeOverride(finalSize);
            }
            catch
            {
                // If arrange fails due to invalid bitmap, clear source and retry
                Source = null;
                return base.ArrangeOverride(finalSize);
            }
        }

        private static IImage? GeneratePlaceholderForProduct(string? productName)
        {
            // Return null so the parent Border background shows through.
            // Using RenderTargetBitmap as a placeholder caused NRE on window resize/fullscreen
            // because it holds a reference to the compositor surface that becomes invalid.
            return null;
        }
    }
}
