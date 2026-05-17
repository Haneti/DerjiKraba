using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace AvaloniaApplication1.Models
{
    /// <summary>
    /// Детали адреса доставки из JSON delivery_details
    /// </summary>
    public class DeliveryAddressDetails
    {
        [JsonPropertyName("address")]
        public string Address { get; set; } = "";

        [JsonPropertyName("house_type")]
        public string HouseType { get; set; } = "apartment";

        [JsonPropertyName("entrance")]
        public string? Entrance { get; set; }

        [JsonPropertyName("floor")]
        public string? Floor { get; set; }

        [JsonPropertyName("apartment")]
        public string? Apartment { get; set; }

        [JsonPropertyName("intercom")]
        public string? Intercom { get; set; }

        [JsonPropertyName("intercom_broken")]
        public bool IntercomBroken { get; set; }

        [JsonPropertyName("latitude")]
        public double? Latitude { get; set; }

        [JsonPropertyName("longitude")]
        public double? Longitude { get; set; }

        public bool IsApartment => HouseType == "apartment";
        public bool IsHouse => HouseType == "house";

        public string FormattedDetails
        {
            get
            {
                var parts = new List<string>();
                
                if (IsApartment)
                {
                    if (!string.IsNullOrEmpty(Entrance))
                        parts.Add($"подъезд {Entrance}");
                    if (!string.IsNullOrEmpty(Floor))
                        parts.Add($"этаж {Floor}");
                    if (!string.IsNullOrEmpty(Apartment))
                        parts.Add($"кв. {Apartment}");
                    if (IntercomBroken)
                        parts.Add("домофон не работает");
                    else if (!string.IsNullOrEmpty(Intercom))
                        parts.Add($"домофон {Intercom}");
                }
                
                return string.Join(", ", parts);
            }
        }
    }

    public class OrderItem
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("productId")]
        public string? ProductId { get; set; }

        [JsonPropertyName("productName")]
        public string? ProductName { get; set; }

        [JsonPropertyName("quantity")]
        public decimal Quantity { get; set; }

        [JsonPropertyName("pricePerKg")]
        public decimal PricePerKg { get; set; }

        public decimal Total => Quantity * PricePerKg;
    }

    public class Customer
    {
        [JsonPropertyName("fullName")]
        public string FullName { get; set; } = string.Empty;

        [JsonPropertyName("phone")]
        public string Phone { get; set; } = string.Empty;

        [JsonPropertyName("address")]
        public string? Address { get; set; }
    }

    public class Order
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("userId")]
        public string UserId { get; set; } = string.Empty;

        [JsonPropertyName("orderDate")]
        public DateTime OrderDate { get; set; }

        [JsonPropertyName("status")]
        public string Status { get; set; } = "pending";

        [JsonPropertyName("deliveryType")]
        public string DeliveryType { get; set; } = string.Empty;

        [JsonPropertyName("deliveryAddress")]
        public string? DeliveryAddress { get; set; }

        [JsonPropertyName("deliveryDetails")]
        public string? DeliveryDetails { get; set; } // JSON с расширенной информацией

        [JsonPropertyName("latitude")]
        public double? Latitude { get; set; }

        [JsonPropertyName("longitude")]
        public double? Longitude { get; set; }

        [JsonPropertyName("totalAmount")]
        public decimal TotalAmount { get; set; }

        [JsonPropertyName("notes")]
        public string? Notes { get; set; }

        [JsonPropertyName("items")]
        public List<OrderItem> Items { get; set; } = new();

        /// <summary>
        /// Парсит delivery_details JSON и возвращает структурированные данные
        /// </summary>
        public DeliveryAddressDetails? ParsedDeliveryDetails
        {
            get
            {
                if (string.IsNullOrEmpty(DeliveryDetails))
                    return null;
                try
                {
                    return System.Text.Json.JsonSerializer.Deserialize<DeliveryAddressDetails>(DeliveryDetails);
                }
                catch
                {
                    return null;
                }
            }
        }

        /// <summary>
        /// Есть ли координаты для отображения на карте
        /// </summary>
        public bool HasCoordinates => Latitude.HasValue && Longitude.HasValue;

        [JsonPropertyName("customer")]
        public Customer? Customer { get; set; }

        public string StatusDisplay => Status switch
        {
            "pending" => "Ожидает подтверждения",
            "processing" => "В обработке",
            "ready" => "Готов к выдаче",
            "delivering" => "Доставляется",
            "completed" => "Завершен",
            "cancelled" => "Отменен",
            _ => Status
        };

        public string DeliveryTypeDisplay => DeliveryType switch
        {
            "pickup" => "Самовывоз",
            "delivery" => "Доставка",
            _ => DeliveryType
        };
    }

    public class OrderCreateRequest
    {
        [JsonPropertyName("user_id")]
        public string UserId { get; set; } = string.Empty;

        [JsonPropertyName("delivery_type")]
        public string DeliveryType { get; set; } = string.Empty;

        [JsonPropertyName("delivery_address")]
        public string? DeliveryAddress { get; set; }

        [JsonPropertyName("notes")]
        public string? Notes { get; set; }

        [JsonPropertyName("items")]
        public List<OrderItemRequest> Items { get; set; } = new();
    }

    public class OrderItemRequest
    {
        [JsonPropertyName("product_id")]
        public string? ProductId { get; set; }

        [JsonPropertyName("quantity")]
        public decimal Quantity { get; set; }

        [JsonPropertyName("price_per_kg")]
        public decimal PricePerKg { get; set; }
    }
}
