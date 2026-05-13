using System;
using System.Text.Json.Serialization;

namespace AvaloniaApplication1.Models
{
    public class Product
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("category")]
        public string Category { get; set; } = string.Empty;

        [JsonPropertyName("pricePerKg")]
        public decimal PricePerKg { get; set; }

        [JsonPropertyName("quantityInStock")]
        public decimal QuantityInStock { get; set; }

        [JsonPropertyName("deliveryDate")]
        public DateTime? DeliveryDate { get; set; }

        [JsonPropertyName("expiryDate")]
        public DateTime? ExpiryDate { get; set; }

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("isAvailable")]
        public bool IsAvailable { get; set; } = true;

        [JsonPropertyName("unitType")]
        public string UnitType { get; set; } = "kg";

        [JsonPropertyName("imageURL")]
        public string? ImageURL { get; set; }

        [JsonPropertyName("imageHash")]
        public string? ImageHash { get; set; }

        public string DisplayPrice => $"{PricePerKg:F2} ₽/{(UnitType == "piece" ? "шт" : "кг")}";
        public string StockStatus => QuantityInStock > 0 ? $"В наличии: {QuantityInStock:F0} {UnitType}" : "Нет в наличии";
        
        /// <summary>
        /// True if expiry date is within 14 days from today
        /// </summary>
        public bool IsExpiringSoon
        {
            get
            {
                if (!ExpiryDate.HasValue) return false;
                var daysLeft = (ExpiryDate.Value.Date - DateTime.Today).TotalDays;
                return daysLeft >= 0 && daysLeft < 14;
            }
        }

        /// <summary>
        /// Color for expiry warning: Green if hidden (already taken care of), Red if available
        /// </summary>
        public string ExpiryColor
        {
            get
            {
                if (!IsExpiringSoon) return "Transparent";
                // If product is hidden, show green (it's already taken care of)
                // If product is available, show red warning
                return IsAvailable ? "#DC2626" : "#16A34A";
            }
        }

        /// <summary>
        /// Text for expiry warning
        /// </summary>
        public string ExpiryText
        {
            get
            {
                if (!IsExpiringSoon || !ExpiryDate.HasValue) return "";
                var daysLeft = (ExpiryDate.Value.Date - DateTime.Today).TotalDays;
                if (IsAvailable)
                    return $"⚠ Срок: {daysLeft:F0} дн.";
                else
                    return $"✓ Скрыт: {daysLeft:F0} дн.";
            }
        }
    }
}
