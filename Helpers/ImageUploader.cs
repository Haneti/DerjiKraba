using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;

namespace AvaloniaApplication1.Helpers
{
    /// <summary>
    /// Uploads product images to server
    /// </summary>
    public class ImageUploader
    {
        private static ImageUploader? _instance;
        public static ImageUploader Instance => _instance ??= new ImageUploader();

        private readonly string _baseURL = "http://87.225.104.51:3000";
        private readonly HttpClient _httpClient;

        private ImageUploader()
        {
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(60)
            };
        }

        /// <summary>
        /// Upload product image to server
        /// </summary>
        /// <param name="imagePath">Path to image file</param>
        /// <param name="productId">Product ID (UUID string)</param>
        /// <returns>Image URL and hash from server</returns>
        public async Task<(string Url, string Hash)> UploadProductImageAsync(string imagePath, string productId)
        {
            if (!File.Exists(imagePath))
                throw new FileNotFoundException("Image file not found", imagePath);

            var url = $"{_baseURL}/products/{productId}/image";
            
            // Read image as JPEG
            using var imageStream = File.OpenRead(imagePath);
            using var memoryStream = new MemoryStream();
            
            // Convert to JPEG if needed (for simplicity, assuming input is already JPEG/PNG)
            await imageStream.CopyToAsync(memoryStream);
            var imageData = memoryStream.ToArray();

            // Create multipart/form-data request
            using var content = new MultipartFormDataContent($"----WebKitFormBoundary{Guid.NewGuid():N}");
            
            var imageContent = new ByteArrayContent(imageData);
            imageContent.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
            content.Add(imageContent, "image", $"product_{productId}.jpg");

            try
            {
                var response = await _httpClient.PostAsync(url, content);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    throw new Exception($"Upload failed: {response.StatusCode} - {errorContent}");
                }

                // Parse response
                var responseContent = await response.Content.ReadAsStringAsync();
                var json = JsonSerializer.Deserialize<UploadResponse>(responseContent);
                
                if (json == null || !json.Ok || string.IsNullOrEmpty(json.ImageUrl) || string.IsNullOrEmpty(json.ImageHash))
                {
                    throw new Exception("Invalid server response");
                }

                Console.WriteLine($"✅ Image uploaded: {json.ImageUrl}");
                return (json.ImageUrl, json.ImageHash);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Upload error: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Delete product image from server
        /// </summary>
        /// <param name="productId">Product ID</param>
        public async Task DeleteProductImageAsync(string productId)
        {
            var url = $"{_baseURL}/products/{productId}/image";
            
            try
            {
                var response = await _httpClient.DeleteAsync(url);
                
                if (!response.IsSuccessStatusCode)
                {
                    throw new Exception($"Delete failed: {response.StatusCode}");
                }

                Console.WriteLine("✅ Image deleted");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Delete error: {ex.Message}");
                throw;
            }
        }

        private class UploadResponse
        {
            public bool Ok { get; set; }
            public string? ImageUrl { get; set; }
            public string? ImageHash { get; set; }
        }
    }
}
