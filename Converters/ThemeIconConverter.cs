using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace AvaloniaApplication1.Converters
{
    public class ThemeIconConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            return value is bool isDarkMode ? (isDarkMode ? "☀️" : "🌙") : "🌙";
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
