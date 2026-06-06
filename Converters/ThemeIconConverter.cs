using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

namespace AvaloniaApplication1.Converters
{
    public class ThemeIconConverter : IValueConverter
    {
        private readonly Lazy<Bitmap> _sun = new(() => LoadIcon("sun"));
        private readonly Lazy<Bitmap> _moon = new(() => LoadIcon("moon"));

        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            var isDarkMode = value is bool dark && dark;
            return isDarkMode ? _sun.Value : _moon.Value;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }

        private static Bitmap LoadIcon(string iconName)
        {
            var uri = new Uri($"avares://AvaloniaApplication1/icons/{iconName}.png");
            using var stream = AssetLoader.Open(uri);
            return new Bitmap(stream);
        }
    }
}
