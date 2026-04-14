using System;
using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;

namespace AvaloniaApplication1.Helpers
{
    /// <summary>
    /// Helper to generate placeholder images based on product name
    /// </summary>
    public static class ImagePlaceholderGenerator
    {
        private static readonly string[] Emojis = { "🦀", "🐟", "🦐", "🦑", "🐚", "🍤" };
        
        public static RenderTargetBitmap GeneratePlaceholder(string productName)
        {
            const int width = 200;
            const int height = 200;
            
            var bitmap = new RenderTargetBitmap(new PixelSize(width, height), new Vector(96, 96));
            
            using (var context = bitmap.CreateDrawingContext())
            {
                // Background
                var lightBlueBrush = new SolidColorBrush(Color.FromRgb(219, 234, 254));
                context.FillRectangle(lightBlueBrush, new Rect(0, 0, width, height));
                
                // Get emoji based on product name hash
                var emojiIndex = Math.Abs(productName.GetHashCode()) % Emojis.Length;
                var emoji = Emojis[emojiIndex];
                
                // Draw emoji centered
                var formattedText = new FormattedText(
                    emoji,
                    CultureInfo.CurrentCulture,
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
    }
}
