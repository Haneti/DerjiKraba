using System;
using System.Globalization;
using System.Text.RegularExpressions;
using Avalonia.Data.Converters;

namespace AvaloniaApplication1.Converters
{
    public class ImageUrlConverter : IValueConverter
    {
        private static readonly Regex ImageMarkdownRegex = new Regex(@"\[\[image\]\](.*?)(?:\s|$)", RegexOptions.Compiled);

        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string text)
            {
                // Extract image URL from [[image]]URL pattern
                var match = ImageMarkdownRegex.Match(text);
                if (match.Success && match.Groups.Count > 1)
                {
                    var url = match.Groups[1].Value.Trim();
                    // If parameter is "Check", return boolean
                    if (parameter?.ToString() == "Check")
                    {
                        return !string.IsNullOrEmpty(url);
                    }
                    return url;
                }
            }
            // If parameter is "Check", return false
            if (parameter?.ToString() == "Check")
            {
                return false;
            }
            return null;
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }

    public class RemoveImageMarkdownConverter : IValueConverter
    {
        private static readonly Regex ImageMarkdownRegex = new Regex(@"\[\[image\]\](.*?)(?:\s|$)", RegexOptions.Compiled);

        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            if (value is string text)
            {
                // Remove [[image]]URL from text
                var cleanedText = ImageMarkdownRegex.Replace(text, "").Trim();
                return string.IsNullOrWhiteSpace(cleanedText) ? null : cleanedText;
            }
            return value;
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo? culture)
        {
            throw new NotImplementedException();
        }
    }
}
