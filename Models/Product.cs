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
        /// True if product is expired (expiry date passed)
        /// </summary>
        public bool IsExpired
        {
            get
            {
                if (!ExpiryDate.HasValue) return false;
                return ExpiryDate.Value.Date < DateTime.Today;
            }
        }
        
        /// <summary>
        /// True if expiry date is within 14 days from today or already expired
        /// </summary>
        public bool IsExpiringSoon
        {
            get
            {
                if (!ExpiryDate.HasValue) return false;
                var daysLeft = (ExpiryDate.Value.Date - DateTime.Today).TotalDays;
                // Show warning if expired (daysLeft < 0) or expiring within 14 days
                return daysLeft < 14;
            }
        }

        /// <summary>
        /// Color for expiry warning: Red for expired or urgent, Orange for warning, Green if hidden
        /// </summary>
        public string ExpiryColor
        {
            get
            {
                if (!IsExpiringSoon) return "Transparent";
                // Expired - always red
                if (IsExpired) return "#DC2626";
                // Expiring soon (< 2 days) - red
                if (!ExpiryDate.HasValue) return "#DC2626";
                var daysLeft = (ExpiryDate.Value.Date - DateTime.Today).TotalDays;
                if (daysLeft <= 2) return "#DC2626";
                // Expiring within 14 days - orange
                if (daysLeft < 14) return "#F97316";
                // If product is hidden and not urgent, show green
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
                
                // Expired
                if (IsExpired)
                    return $"⚠ ПРОСРОЧЕН: {Math.Abs(daysLeft):F0} дн.!";
                
                // Expiring soon
                if (IsAvailable)
                    return $"⚠ Срок: {daysLeft:F0} дн.";
                else
                    return $"✓ Скрыт: {daysLeft:F0} дн.";
            }
        }
        
        /// <summary>
        /// Icon for expiry status
        /// </summary>
        public string ExpiryIcon => IsExpired ? "⚠️" : (IsExpiringSoon ? "⏰" : "");
    }
}
