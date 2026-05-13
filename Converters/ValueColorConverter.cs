using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace AvaloniaApplication1.Converters
{
    /// <summary>
    /// Converts a decimal value to a color brush (red for negative, green for positive, gray for zero)
    /// </summary>
    public class ValueColorConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is decimal decimalValue)
            {
                if (decimalValue < 0)
                    return new SolidColorBrush(Color.Parse("#DC2626")); // Red
                if (decimalValue > 0)
                    return new SolidColorBrush(Color.Parse("#16A34A")); // Green
                return new SolidColorBrush(Color.Parse("#6B7280")); // Gray
            }
            
            return new SolidColorBrush(Color.Parse("#6B7280"));
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
