using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace AvaloniaApplication1.Models
{
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

        [JsonPropertyName("totalAmount")]
        public decimal TotalAmount { get; set; }

        [JsonPropertyName("notes")]
        public string? Notes { get; set; }

        [JsonPropertyName("items")]
        public List<OrderItem> Items { get; set; } = new();

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
