using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace AvaloniaApplication1.Models
{
    /// <summary>
    /// Inventory item for stocktaking (matches iOS InventoryItem)
    /// </summary>
    public class InventoryItem
    {
        [JsonPropertyName("productId")]
        public string ProductId { get; set; } = string.Empty;
        
        [JsonPropertyName("productName")]
        public string ProductName { get; set; } = string.Empty;
        
        [JsonPropertyName("category")]
        public string Category { get; set; } = string.Empty;
        
        [JsonPropertyName("systemQuantity")]
        public decimal SystemQuantity { get; set; }
        
        [JsonPropertyName("actualQuantity")]
        public decimal ActualQuantity { get; set; }
        
        [JsonPropertyName("unitType")]
        public string UnitType { get; set; } = "kg";
        
        /// <summary>
        /// Difference between actual and system quantity
        /// </summary>
        [JsonIgnore]
        public decimal Difference => ActualQuantity - SystemQuantity;
        
        /// <summary>
        /// Type of adjustment needed
        /// </summary>
        [JsonIgnore]
        public AdjustmentType AdjustmentType
        {
            get
            {
                if (Difference < -0.01m) return AdjustmentType.Shortage;
                if (Difference > 0.01m) return AdjustmentType.Surplus;
                return AdjustmentType.Normal;
            }
        }
        
        /// <summary>
        /// Display formatted difference
        /// </summary>
        [JsonIgnore]
        public string DisplayDifference
        {
            get
            {
                var sign = Difference >= 0 ? "+" : "";
                return $"{sign}{Difference:F2} {UnitType}";
            }
        }
        
        /// <summary>
        /// Display color for difference
        /// </summary>
        [JsonIgnore]
        public string DifferenceColor
        {
            get
            {
                return AdjustmentType switch
                {
                    AdjustmentType.Shortage => "#DC2626", // Red
                    AdjustmentType.Surplus => "#16A34A",  // Green
                    AdjustmentType.Normal => "#6B7280",   // Gray
                    _ => "#6B7280"                         // Default
                };
            }
        }
    }
    
    /// <summary>
    /// Type of inventory adjustment
    /// </summary>
    public enum AdjustmentType
    {
        Normal,      // No significant difference
        Shortage,    // Actual < System
        Surplus      // Actual > System
    }
    
    /// <summary>
    /// Request to apply inventory adjustments
    /// </summary>
    public class InventoryAdjustmentRequest
    {
        [JsonPropertyName("items")]
        public List<InventoryAdjustmentItem> Items { get; set; } = new();
    }
    
    /// <summary>
    /// Single inventory adjustment item
    /// </summary>
    public class InventoryAdjustmentItem
    {
        [JsonPropertyName("productId")]
        public string ProductId { get; set; } = string.Empty;
        
        [JsonPropertyName("actualQuantity")]
        public decimal ActualQuantity { get; set; }
        
        [JsonPropertyName("comment")]
        public string? Comment { get; set; }
    }
}
