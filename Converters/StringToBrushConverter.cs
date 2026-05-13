using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace AvaloniaApplication1.Converters
{
    /// <summary>
    /// Converts a hex color string (#RRGGBB or #AARRGGBB) to SolidColorBrush.
    /// </summary>
    public class StringToBrushConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string hex && !string.IsNullOrEmpty(hex))
            {
                try
                {
                    return new SolidColorBrush(Color.Parse(hex));
                }
                catch
                {
                    return new SolidColorBrush(Colors.Gray);
                }
            }
            return new SolidColorBrush(Colors.Gray);
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
