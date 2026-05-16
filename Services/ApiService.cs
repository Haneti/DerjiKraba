using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using AvaloniaApplication1.Models;

namespace AvaloniaApplication1.Services
{
    public class ApiService
    {
        private readonly HttpClient _httpClient;
        private readonly JsonSerializerOptions _jsonOptions;

        public ApiService()
        {
            _httpClient = new HttpClient
            {
                BaseAddress = new Uri("https://derji-kraba.ru/api")
            };
            
            _jsonOptions = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
        }

        // Health check
        public async Task<bool> CheckHealthAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/health");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        #region Authentication

        public async Task<User?> LoginAsync(string phone)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new { phone }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/auth/login", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<User>(_jsonOptions);
                }
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Login error: {ex.Message}");
                return null;
            }
        }

        public async Task<User?> RegisterAsync(string phone, string firstName, string lastName, string? middleName = null)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new { phone, first_name = firstName, last_name = lastName, middle_name = middleName }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/auth/register", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<User>(_jsonOptions);
                }
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Register error: {ex.Message}");
                return null;
            }
        }

        public async Task<bool> RequestVerificationCodeAsync(string phone)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new { phone }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/auth/request-code", content);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<User?> VerifyCodeAsync(string phone, string code)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new { phone, code }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/auth/verify-code", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<User>(_jsonOptions);
                }
                return null;
            }
            catch
            {
                return null;
            }
        }

        #endregion

        #region Products

        public async Task<List<Product>> GetProductsAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/products");
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<List<Product>>(_jsonOptions) ?? new List<Product>();
                }
                return new List<Product>();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Get products error: {ex.Message}");
                return new List<Product>();
            }
        }

        public async Task<Product?> CreateProductAsync(Product product)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new
                    {
                        product.Name,
                        product.Category,
                        price_per_kg = product.PricePerKg,
                        quantity_in_stock = product.QuantityInStock,
                        delivery_date = product.DeliveryDate,
                        expiry_date = product.ExpiryDate,
                        product.Description,
                        is_available = product.IsAvailable,
                        unit_type = product.UnitType
                    }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/products", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<Product>(_jsonOptions);
                }
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Create product error: {ex.Message}");
                return null;
            }
        }

        public async Task<Product?> UpdateProductAsync(string id, Product product)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new
                    {
                        product.Name,
                        product.Category,
                        price_per_kg = product.PricePerKg,
                        quantity_in_stock = product.QuantityInStock,
                        delivery_date = product.DeliveryDate,
                        expiry_date = product.ExpiryDate,
                        product.Description,
                        is_available = product.IsAvailable,
                        unit_type = product.UnitType
                    }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PatchAsync($"/products/{id}", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<Product>(_jsonOptions);
                }
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Update product error: {ex.Message}");
                return null;
            }
        }

        public async Task<bool> DeleteProductAsync(string id)
        {
            try
            {
                var response = await _httpClient.DeleteAsync($"/products/{id}");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<(string Url, string Hash)?> UploadProductImageAsync(string productId, string filePath)
        {
            try
            {
                if (!File.Exists(filePath))
                {
                    Console.WriteLine($"❌ File not found: {filePath}");
                    return null;
                }

                var fileName = $"product_{productId}.jpg";
                var fileBytes = await File.ReadAllBytesAsync(filePath);
                var boundary = Guid.NewGuid().ToString();

                using var content = new MultipartFormDataContent($"--{boundary}");
                using var fileContent = new ByteArrayContent(fileBytes);
                fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg");
                content.Add(fileContent, "image", fileName);

                var response = await _httpClient.PostAsync($"/products/{productId}/image", content);

                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadFromJsonAsync<ProductImageUploadResponse>(_jsonOptions);
                    if (json?.Ok == true && json.ImageUrl != null && json.ImageHash != null)
                    {
                        Console.WriteLine($"✅ Image uploaded: {json.ImageUrl}");
                        return (json.ImageUrl, json.ImageHash);
                    }
                    Console.WriteLine($"❌ Image upload: unexpected response");
                    return null;
                }

                var error = await response.Content.ReadAsStringAsync();
                Console.WriteLine($"❌ Image upload failed: {response.StatusCode} — {error}");
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ UploadProductImage error: {ex.Message}");
                return null;
            }
        }

        public async Task<bool> DeleteProductImageAsync(string productId)
        {
            try
            {
                var response = await _httpClient.DeleteAsync($"/products/{productId}/image");
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ DeleteProductImage error: {ex.Message}");
                return false;
            }
        }

        private class ProductImageUploadResponse
        {
            public bool Ok { get; set; }
            public string? ImageUrl { get; set; }
            public string? ImageHash { get; set; }
        }

        #endregion

        #region Inventory

        public async Task<bool> ApplyInventoryAdjustmentAsync(InventoryAdjustmentRequest request)
        {
            try
            {
                Console.WriteLine($"📦 Applying inventory adjustment for {request.Items.Count} items");
                
                var response = await _httpClient.PostAsJsonAsync("/inventory/adjustments", request, _jsonOptions);
                
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine("✅ Inventory adjustment successful");
                    return true;
                }
                else
                {
                    Console.WriteLine($"❌ Inventory adjustment failed: {response.StatusCode}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Inventory adjustment error: {ex.Message}");
                return false;
            }
        }

        #endregion

        #region Orders

        public async Task<List<Order>> GetOrdersAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/orders");
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<List<Order>>(_jsonOptions) ?? new List<Order>();
                }
                return new List<Order>();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Get orders error: {ex.Message}");
                return new List<Order>();
            }
        }

        public async Task<List<Order>> GetOrdersByUserAsync(string userId)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/orders/user/{userId}");
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<List<Order>>(_jsonOptions) ?? new List<Order>();
                }
                return new List<Order>();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Get user orders error: {ex.Message}");
                return new List<Order>();
            }
        }

        public async Task<Order?> CreateOrderAsync(OrderCreateRequest order)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(order),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/orders", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<Order>(_jsonOptions);
                }
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Create order error: {ex.Message}");
                return null;
            }
        }

        public async Task<bool> UpdateOrderStatusAsync(string orderId, string status)
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new { status }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PatchAsync($"/orders/{orderId}", content);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        #endregion

        #region Support Chat

        public async Task<List<SupportConversation>> GetConversationsAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/support/conversations");
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<List<SupportConversation>>(_jsonOptions) ?? new List<SupportConversation>();
                }
                return new List<SupportConversation>();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Get conversations error: {ex.Message}");
                return new List<SupportConversation>();
            }
        }

        public async Task<SupportConversation?> GetConversationAsync(string phone)
        {
            try
            {
                var response = await _httpClient.GetAsync($"/support/conversations/{phone}");
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<SupportConversation>(_jsonOptions);
                }
                return null;
            }
            catch
            {
                return null;
            }
        }

        public async Task<List<SupportMessage>> GetMessagesAsync(string phone)
        {
            Console.WriteLine($"🌐 [API] GetMessagesAsync called with phone: {phone}");
            
            try
            {
                var response = await _httpClient.GetAsync($"/support/conversations/{phone}/messages");
                if (response.IsSuccessStatusCode)
                {
                    var messages = await response.Content.ReadFromJsonAsync<List<SupportMessage>>(_jsonOptions) ?? new List<SupportMessage>();
                    Console.WriteLine($"✅ [API] Retrieved {messages.Count} messages for {phone}");
                    return messages;
                }
                else
                {
                    Console.WriteLine($"❌ [API] GetMessages failed with status: {response.StatusCode}");
                    return new List<SupportMessage>();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ [API] GetMessages error: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return new List<SupportMessage>();
            }
        }

        public async Task<bool> SendMessageAsync(string clientPhone, string senderPhone, string text, string? imageUrl = null)
        {
            try
            {
                var payload = new { clientPhone, senderPhone, text, imageURL = imageUrl };
                var content = new StringContent(
                    JsonSerializer.Serialize(payload),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync($"/support/conversations/{clientPhone}/messages", content);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Send message error: {ex.Message}");
                return false;
            }
        }

        public async Task<string?> UploadImageAsync(string filePath)
        {
            try
            {
                if (!File.Exists(filePath))
                {
                    Console.WriteLine($"❌ File not found: {filePath}");
                    return null;
                }

                var fileName = Path.GetFileName(filePath);
                var fileBytes = await File.ReadAllBytesAsync(filePath);
                
                using var content = new MultipartFormDataContent();
                using var fileContent = new ByteArrayContent(fileBytes);
                fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg");
                content.Add(fileContent, "image", fileName);

                var response = await _httpClient.PostAsync("/upload", content);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<UploadResponse>(_jsonOptions);
                    Console.WriteLine($"✅ Image uploaded: {result?.Url}");
                    return result?.Url;
                }
                else
                {
                    Console.WriteLine($"❌ Image upload failed: {response.StatusCode}");
                    var error = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Error: {error}");
                    return null;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Upload image error: {ex.Message}");
                return null;
            }
        }

        private class UploadResponse
        {
            public string? Url { get; set; }
        }

        #endregion

        #region Staff

        public async Task<User?> CreateStaffAsync(string phone, string firstName, string lastName, string? middleName = null, string role = "employee")
        {
            try
            {
                var content = new StringContent(
                    JsonSerializer.Serialize(new { phone, first_name = firstName, last_name = lastName, middle_name = middleName, role }),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/staff/create", content);
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<User>(_jsonOptions);
                }
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Create staff error: {ex.Message}");
                return null;
            }
        }

        public async Task<List<User>> GetAllUsersAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/users");
                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<List<User>>(_jsonOptions) ?? new List<User>();
                }
                return new List<User>();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Get all users error: {ex.Message}");
                return new List<User>();
            }
        }

        public async Task<bool> UpdateUserRoleAsync(string userId, string role)
        {
            try
            {
                Console.WriteLine($"🔄 Updating user {userId} role to {role}");
                
                var content = new StringContent(
                    JsonSerializer.Serialize(new { role }),
                    Encoding.UTF8,
                    "application/json"
                );

                // Try different possible endpoints
                var response = await _httpClient.PatchAsync($"/staff/update-role/{userId}", content);
                
                if (!response.IsSuccessStatusCode)
                {
                    // Fallback to users endpoint if staff endpoint doesn't work
                    Console.WriteLine($"⚠️ First attempt failed, trying fallback endpoint...");
                    response = await _httpClient.PatchAsync($"/users/{userId}/role", content);
                }
                
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"✅ User role updated successfully");
                    return true;
                }
                else
                {
                    Console.WriteLine($"❌ Role update failed: {response.StatusCode}");
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Error details: {errorContent}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Update role error: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return false;
            }
        }

        public async Task<bool> DeleteUserAsync(string userId)
        {
            try
            {
                Console.WriteLine($"🗑️ Deleting user {userId}");
                
                var response = await _httpClient.DeleteAsync($"/users/{userId}");
                
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"✅ User deleted successfully");
                    return true;
                }
                else
                {
                    Console.WriteLine($"❌ Delete user failed: {response.StatusCode}");
                    var errorContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"Error details: {errorContent}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Delete user error: {ex.Message}");
                return false;
            }
        }

        #endregion
    }
}
