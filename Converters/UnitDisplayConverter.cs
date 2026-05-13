using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace AvaloniaApplication1.Converters
{
    public class UnitDisplayConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string unit)
            {
                return unit switch
                {
                    "kg" => "кг",
                    "piece" => "шт",
                    _ => unit
                };
            }
            return value;
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string unit)
            {
                return unit switch
                {
                    "кг" => "kg",
                    "шт" => "piece",
                    _ => unit
                };
            }
            return value;
        }
    }
}
