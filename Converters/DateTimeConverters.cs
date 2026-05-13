using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace AvaloniaApplication1.Converters
{
    public class DateTimeToDateTimeOffsetConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is DateTime dateTime)
            {
                return new DateTimeOffset(dateTime);
            }
            if (value is DateTime dt)
            {
                return new DateTimeOffset(dt);
            }
            return null;
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is DateTimeOffset dto)
            {
                return dto.DateTime;
            }
            return null;
        }
    }

    public class DateTimeDisplayConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is DateTime dateTime)
            {
                return dateTime.ToString("dd.MM.yyyy");
            }
            return "—";
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
