using System;
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

        public bool IsFromStaff => SenderRole == "employee" || SenderRole == "admin";
        public string Time => CreatedAt.ToString("HH:mm");
    }
}
