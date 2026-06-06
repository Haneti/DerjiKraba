using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace AvaloniaApplication1.Converters
{
    /// <summary>
    /// Converts boolean to border brush for selection highlighting or error states
    /// </summary>
    public class BoolToBorderBrushConverter : IValueConverter
    {
        public Brush FalseBrush { get; set; } = new SolidColorBrush(Color.FromRgb(229, 231, 235)); // #E5E7EB - gray
        public Brush TrueBrush { get; set; } = new SolidColorBrush(Color.FromRgb(37, 99, 235)); // #2563EB - blue
        public Brush ErrorBrush { get; set; } = new SolidColorBrush(Color.FromRgb(220, 38, 38)); // #DC2626 - red
        public Brush OutOfStockBrush { get; set; } = new SolidColorBrush(Color.FromRgb(249, 115, 22)); // #F97316 - orange

        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            // Parameter can specify which mode to use: "error" for error highlighting
            var mode = parameter?.ToString();

            if (value is bool boolValue)
            {
                if (mode == "error" && boolValue)
                    return ErrorBrush;
                return boolValue ? TrueBrush : FalseBrush;
            }

            // Support int AlertLevel: 0 = normal, 1 = out of stock, 2 = expired
            if (value is int alertLevel)
            {
                return alertLevel switch
                {
                    2 => ErrorBrush,
                    1 => OutOfStockBrush,
                    _ => FalseBrush,
                };
            }

            return FalseBrush;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}
