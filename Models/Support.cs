using System;
using System.Linq;
using System.Text.Json.Serialization;

namespace AvaloniaApplication1.Models
{
    public class SupportConversation
    {
        [JsonPropertyName("clientPhone")]
        public string ClientPhone { get; set; } = string.Empty;

        [JsonPropertyName("clientName")]
        public string ClientName { get; set; } = string.Empty;

        [JsonPropertyName("lastMessageAt")]
        public DateTime? LastMessageAt { get; set; }

        [JsonPropertyName("lastMessageText")]
        public string? LastMessageText { get; set; }

        [JsonPropertyName("lastSenderRole")]
        public string? LastSenderRole { get; set; }

        [JsonPropertyName("needsStaffReply")]
        public bool NeedsStaffReply { get; set; }

        public string LastMessagePreview
        {
            get
            {
                if (string.IsNullOrEmpty(LastMessageText))
                    return "Нет сообщений";

                return LastMessageText.Length > 50
                    ? LastMessageText.Substring(0, 50) + "..."
                    : LastMessageText;
            }
        }

        public string LastMessageTime => LastMessageAt?.ToString("dd.MM.yyyy HH:mm") ?? "";
        
        /// <summary>
        /// Status indicator color: red if needs reply, gray otherwise (mobile style)
        /// </summary>
        public string StatusDotColor => NeedsStaffReply ? "#EF4444" : "#9CA3AF";
        
        /// <summary>
        /// Formatted phone for display: +7 (XXX) XXX-XX-XX
        /// </summary>
        public string FormattedPhone
        {
            get
            {
                if (string.IsNullOrEmpty(ClientPhone)) return "";
                var digits = new string(ClientPhone.Where(char.IsDigit).ToArray());
                if (digits.Length == 11 && (digits[0] == '7' || digits[0] == '8'))
                    return $"+7 ({digits.Substring(1, 3)}) {digits.Substring(4, 3)}-{digits.Substring(7, 2)}-{digits.Substring(9, 2)}";
                return ClientPhone;
            }
        }
    }

    public class SupportMessage
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("clientPhone")]
        public string ClientPhone { get; set; } = string.Empty;

        [JsonPropertyName("senderPhone")]
        public string SenderPhone { get; set; } = string.Empty;

        [JsonPropertyName("senderRole")]
        public string SenderRole { get; set; } = string.Empty;

        [JsonPropertyName("text")]
        public string Text { get; set; } = string.Empty;

        [JsonPropertyName("createdAt")]
        public DateTime CreatedAt { get; set; }

        [JsonPropertyName("imageURL")]
        public string? ImageURL { get; set; }

        public bool IsFromStaff => SenderRole == "employee" || SenderRole == "admin" || SenderRole == "owner";
        public bool HasImage => !string.IsNullOrEmpty(ImageURL);
        public string Time => CreatedAt.ToString("HH:mm");
    }
}
