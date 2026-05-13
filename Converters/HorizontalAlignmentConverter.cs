using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Layout;

namespace AvaloniaApplication1.Converters
{
    public class HorizontalAlignmentConverter : IValueConverter
    {
        public object Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            // parameter: "Staff" means return Right for staff (true), Left for client (false)
            // "Client" means return Left for client (true), Right for staff (false)
            if (value is bool isFromStaff)
            {
                var param = parameter?.ToString();
                if (param == "Staff")
                {
                    // Staff messages on right
                    return isFromStaff ? HorizontalAlignment.Right : HorizontalAlignment.Left;
                }
                else if (param == "Client")
                {
                    // Client messages on left
                    return isFromStaff ? HorizontalAlignment.Left : HorizontalAlignment.Right;
                }
            }
            return HorizontalAlignment.Left;
        }

        public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
