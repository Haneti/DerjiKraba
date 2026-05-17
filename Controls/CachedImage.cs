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

                // Then load from cache asynchronously
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

        private static IImage? GeneratePlaceholderForProduct(string? productName)
        {
            try
            {
                const int width = 200;
                const int height = 160;
                
                var bitmap = new RenderTargetBitmap(new PixelSize(width, height), new Vector(96, 96));
                
                using (var context = bitmap.CreateDrawingContext())
                {
                    // Light blue background
                    var lightBlueBrush = new SolidColorBrush(Color.FromRgb(219, 234, 254));
                    context.FillRectangle(lightBlueBrush, new Rect(0, 0, width, height));
                    
                    // Get emoji based on product name or use default crab
                    var emoji = !string.IsNullOrEmpty(productName) 
                        ? GetEmojiForProduct(productName) 
                        : "🦀";
                    
                    // Draw emoji centered - use system default font that supports emoji
                    var formattedText = new FormattedText(
                        emoji,
                        System.Globalization.CultureInfo.CurrentCulture,
                        FlowDirection.LeftToRight,
                        Typeface.Default,
                        80,
                        Brushes.Black);
                    
                    var textX = (width - formattedText.Width) / 2;
                    var textY = (height - formattedText.Height) / 2;
                    
                    context.DrawText(formattedText, new Point(textX, textY));
                }
                
                return bitmap;
            }
            catch
            {
                // Fallback: return null, control will use default behavior
                return null;
            }
        }

        private static string GetEmojiForProduct(string productName)
        {
            var lower = productName.ToLowerInvariant();
            
            if (lower.Contains("краб") || lower.Contains("crab")) return "🦀";
            if (lower.Contains("рыб") || lower.Contains("fish")) return "🐟";
            if (lower.Contains("креветк") || lower.Contains("shrimp")) return "🦐";
            if (lower.Contains("кальмар") || lower.Contains("squid")) return "🦑";
            if (lower.Contains("миди") || lower.Contains("clam")) return "🐚";
            if (lower.Contains("осьминог") || lower.Contains("octopus")) return "🐙";
            
            // Default to crab for unknown products
            return "🦀";
        }
    }
}
