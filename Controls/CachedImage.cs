using System;
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

                // Then load from cache asynchronously
                var bitmap = await ImageCacheManager.Instance.GetImageAsync(SourceUrl, ImageHash);
                
                if (bitmap != null)
                {
                    Source = bitmap;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Failed to load image: {ex.Message}");
                Source = GeneratePlaceholderForProduct(ProductName);
            }
        }

        private static RenderTargetBitmap GeneratePlaceholderForProduct(string? productName)
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
                
                // Draw emoji centered
                var formattedText = new FormattedText(
                    emoji,
                    System.Globalization.CultureInfo.CurrentCulture,
                    FlowDirection.LeftToRight,
                    new Typeface("Segoe UI Emoji"),
                    80,
                    Brushes.Black);
                
                var textX = (width - formattedText.Width) / 2;
                var textY = (height - formattedText.Height) / 2;
                
                context.DrawText(formattedText, new Point(textX, textY));
            }
            
            return bitmap;
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
