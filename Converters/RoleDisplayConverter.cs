using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace AvaloniaApplication1.Converters
{
    public class RoleDisplayConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string role)
            {
                return role.ToLower() switch
                {
                    "owner" => "Владелец",
                    "employee" => "Сотрудник",
                    "client" => "Клиент",
                    "admin" => "Администратор",
                    _ => role
                };
            }
            return value;
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string role)
            {
                return role switch
                {
                    "Владелец" => "owner",
                    "Сотрудник" => "employee",
                    "Клиент" => "client",
                    "Администратор" => "admin",
                    _ => value
                };
            }
            return value;
        }
    }
}
