using System;
using System.Text.Json.Serialization;

namespace AvaloniaApplication1.Models
{
    public class User
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("phone")]
        public string Phone { get; set; } = string.Empty;

        [JsonPropertyName("firstName")]
        public string FirstName { get; set; } = string.Empty;

        [JsonPropertyName("lastName")]
        public string LastName { get; set; } = string.Empty;

        [JsonPropertyName("middleName")]
        public string? MiddleName { get; set; }

        [JsonPropertyName("role")]
        public string Role { get; set; } = string.Empty;

        [JsonPropertyName("isVerified")]
        public bool IsVerified { get; set; }

        public bool IsStaff => Role == "admin" || Role == "employee" || Role == "owner";
        
        public bool IsOwner => Role == "admin" || Role == "owner";

        public string FullName => $"{LastName} {FirstName} {MiddleName}".Trim();
    }
}
