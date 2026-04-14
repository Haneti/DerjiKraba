using System;
using System.Globalization;
using System.Threading.Tasks;
using Avalonia.Data.Converters;
using Avalonia.Media.Imaging;
using AvaloniaApplication1.Helpers;
using AvaloniaApplication1.Models;

namespace AvaloniaApplication1.Converters
{
    /// <summary>
    /// Converts product to cached bitmap
    /// </summary>
    public class ProductImageConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            if (value is not Product product)
                return null;

            // If no image URL, generate placeholder
            if (string.IsNullOrEmpty(product.ImageURL))
            {
                return ImagePlaceholderGenerator.GeneratePlaceholder(product.Name);
            }

            // Load from cache (async but we're in converter, so return placeholder first)
            // For proper async loading, we'd need a more complex approach with INotifyPropertyChanged
            Task.Run(async () =>
            {
                var bitmap = await ImageCacheManager.Instance.GetImageAsync(product.ImageURL!, product.ImageHash);
                return bitmap;
            });

            // Return placeholder while loading
            return ImagePlaceholderGenerator.GeneratePlaceholder(product.Name);
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}
