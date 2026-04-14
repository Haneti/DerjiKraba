using System;
using System.Linq;
using System.Text.RegularExpressions;

namespace AvaloniaApplication1.Helpers
{
    /// <summary>
    /// Phone number formatter and normalizer (same logic as iOS Swift version)
    /// </summary>
    public static class PhoneFormatter
    {
        /// <summary>
        /// Formats phone number to beautiful view: +7 (984) 175-29-98
        /// </summary>
        public static string Format(string phone)
        {
            // Remove all non-digit characters
            var digits = new string(phone.Where(char.IsDigit).ToArray());
            
            // If starts with 8, replace with 7
            if (!string.IsNullOrEmpty(digits) && digits[0] == '8')
            {
                digits = "7" + digits.Substring(1);
            }
            
            // If doesn't start with 7, add 7
            if (!string.IsNullOrEmpty(digits) && digits[0] != '7')
            {
                digits = "7" + digits;
            }
            
            // Format: +7 (XXX) XXX-XX-XX
            if (digits.Length != 11)
            {
                return $"+7 ({phone})";
            }
            
            var country = digits.Substring(0, 1); // 7
            var code = digits.Substring(1, 3); // 984
            var first = digits.Substring(4, 3); // 175
            var second = digits.Substring(7, 2); // 29
            var third = digits.Substring(9, 2); // 98
            
            return $"+{country} ({code}) {first}-{second}-{third}";
        }
        
        /// <summary>
        /// Cleans phone number from formatting and leaves only digits
        /// </summary>
        public static string Clean(string phone)
        {
            // Remove all non-digit characters
            var digits = new string(phone.Where(char.IsDigit).ToArray());
            
            // If starts with 8, replace with 7
            if (!string.IsNullOrEmpty(digits) && digits[0] == '8')
            {
                digits = "7" + digits.Substring(1);
            }
            
            // If doesn't start with 7, add 7
            if (!string.IsNullOrEmpty(digits) && digits[0] != '7')
            {
                digits = "7" + digits;
            }
            
            return digits;
        }
        
        /// <summary>
        /// Adds +7 to phone if user entered only 10 digits
        /// </summary>
        public static string Normalize(string input)
        {
            var digits = new string(input.Where(char.IsDigit).ToArray());
            
            // If exactly 10 digits, add 7 at the beginning
            if (digits.Length == 10)
            {
                return "7" + digits;
            }
            
            return Clean(input);
        }
        
        /// <summary>
        /// Checks if phone number is valid
        /// </summary>
        public static bool IsValid(string phone)
        {
            var cleaned = Clean(phone);
            return cleaned.Length == 11 && cleaned[0] == '7';
        }
        
        /// <summary>
        /// Normalizes phone to standard format: 7XXXXXXXXXXX
        /// This should be used before sending to API
        /// </summary>
        public static string NormalizeForApi(string phone)
        {
            var result = Normalize(phone);
            Console.WriteLine($"📱 Phone normalized: '{phone}' → '{result}'");
            return result;
        }
    }
}
