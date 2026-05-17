using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace AvaloniaApplication1.Converters
{
    public class MessageForegroundConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            // Staff messages have white text, client messages have dark gray text
            if (value is bool isFromStaff && isFromStaff)
            {
                return new SolidColorBrush(Colors.White);
            }
            // Client messages - dark gray text for visibility on light gray background
            return new SolidColorBrush(Color.Parse("#374151"));
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }

    public class MessageTimeForegroundConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            // Staff: white with opacity, Client: dark gray
            if (value is bool isFromStaff && isFromStaff)
            {
                return new SolidColorBrush(Colors.White);
            }
            // Client messages - medium gray for time
            return new SolidColorBrush(Color.Parse("#6B7280"));
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }

    public class BoolToOpacityConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            // Staff time has 0.75 opacity, client has 1.0
            if (value is bool isFromStaff && isFromStaff)
            {
                return 0.75;
            }
            return 1.0;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }

    public class BoolToBrushConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            var param = parameter?.ToString() ?? "StaffMessageBrush,ClientMessageBrush";
            var parts = param.Split(',');
            var staffBrushKey = parts[0].Trim();
            var clientBrushKey = parts.Length > 1 ? parts[1].Trim() : "ClientMessageBrush";

            if (App.Current?.Resources.TryGetResource(staffBrushKey, null, out var staffBrush) == true &&
                App.Current?.Resources.TryGetResource(clientBrushKey, null, out var clientBrush) == true &&
                staffBrush is IBrush staff && clientBrush is IBrush client)
            {
                if (value is bool isFromStaff && isFromStaff)
                {
                    return staff;
                }
                return client;
            }

            // Fallback
            if (value is bool isStaff && isStaff)
            {
                return new SolidColorBrush(Color.Parse("#3B82F6"));
            }
            return new SolidColorBrush(Color.Parse("#26808080"));
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
