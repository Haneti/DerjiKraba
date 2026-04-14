using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace AvaloniaApplication1.Converters
{
    /// <summary>
    /// Converts boolean to border brush for selection highlighting
    /// </summary>
    public class BoolToBorderBrushConverter : IValueConverter
    {
        public Brush FalseBrush { get; set; } = new SolidColorBrush(Color.FromRgb(229, 231, 235)); // #E5E7EB
        public Brush TrueBrush { get; set; } = new SolidColorBrush(Color.FromRgb(37, 99, 235)); // #2563EB
        
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            if (value is bool isSelected)
            {
                return isSelected ? TrueBrush : FalseBrush;
            }
            return FalseBrush;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}
