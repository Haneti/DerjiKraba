using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Avalonia.Media.Imaging;
using AvaloniaApplication1.Services;

namespace AvaloniaApplication1.Helpers
{
    /// <summary>
    /// Manager for caching product images with hash verification
    /// </summary>
    public class ImageCacheManager
    {
        private static ImageCacheManager? _instance;
        public static ImageCacheManager Instance => _instance ??= new ImageCacheManager();

        private readonly string _cacheDirectory;
        private readonly HttpClient _httpClient;
        private const int MaxCacheSizeBytes = 50 * 1024 * 1024; // 50 MB
        
        // Memory cache for loaded bitmaps to avoid reloading from disk every time
        private readonly Dictionary<string, Bitmap> _memoryCache = new();
        private const int MaxMemoryCacheItems = 100;

        private ImageCacheManager()
        {
            // Cache directory in app's local folder
            var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            _cacheDirectory = Path.Combine(appDataPath, "DerjiKraba", "ImageCache");
            
            Directory.CreateDirectory(_cacheDirectory);
            
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(30)
            };
            
            // Cleanup old cache on startup
            CleanupOldCache();
        }

        /// <summary>
        /// Get image from cache or download from server
        /// </summary>
        /// <param name="url">Image URL</param>
        /// <param name="serverHash">Hash from server for validation</param>
        /// <returns>Cached or downloaded bitmap</returns>
        public async Task<Bitmap?> GetImageAsync(string url, string? serverHash = null)
        {
            if (string.IsNullOrEmpty(url))
                return null;

            var cacheKey = ComputeMD5(url);
            var cacheFilePath = Path.Combine(_cacheDirectory, cacheKey);
            var hashFilePath = cacheFilePath + ".hash";

            try
            {
                // First check memory cache
                if (_memoryCache.TryGetValue(cacheKey, out var cachedBitmap))
                {
                    Console.WriteLine($"⚡ Memory cache hit: {url}");
                    return cachedBitmap;
                }
                
                Console.WriteLine($"🔍 Checking disk cache for: {url}");
                
                // Check if we have cached version on disk
                if (File.Exists(cacheFilePath))
                {
                    Console.WriteLine($"✅ Found cached file: {cacheFilePath}");
                    
                    // If server hash provided, verify it
                    if (!string.IsNullOrEmpty(serverHash))
                    {
                        var storedHash = await ReadStoredHashAsync(hashFilePath);
                        
                        if (storedHash != serverHash)
                        {
                            Console.WriteLine($"⚠️ Hash mismatch. Stored: {storedHash}, Server: {serverHash}. Re-downloading...");
                            // Delete old files
                            TryDeleteFile(cacheFilePath);
                            TryDeleteFile(hashFilePath);
                            // Download new version and add to memory cache
                            var bitmap = await DownloadAndSaveImageAsync(url, serverHash, cacheFilePath, hashFilePath);
                            AddToMemoryCache(cacheKey, bitmap);
                            return bitmap;
                        }
                        else
                        {
                            Console.WriteLine($"✅ Hashes match! Loading from cache: {url}");
                            var bitmap = LoadBitmapFromFile(cacheFilePath);
                            AddToMemoryCache(cacheKey, bitmap);
                            return bitmap;
                        }
                    }
                    else
                    {
                        // No hash to verify, just return cached image
                        Console.WriteLine($"✅ Loading cached image (no hash): {url}");
                        var bitmap = LoadBitmapFromFile(cacheFilePath);
                        AddToMemoryCache(cacheKey, bitmap);
                        return bitmap;
                    }
                }

                // Download from server
                Console.WriteLine($"📥 No cache found, downloading from server: {url}");
                var newBitmap = await DownloadAndSaveImageAsync(url, serverHash, cacheFilePath, hashFilePath);
                AddToMemoryCache(cacheKey, newBitmap);
                return newBitmap;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Image cache error: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return null;
            }
        }

        /// <summary>
        /// Clear all cached images (both memory and disk)
        /// </summary>
        public void ClearCache()
        {
            try
            {
                // Clear memory cache
                foreach (var bitmap in _memoryCache.Values)
                {
                    bitmap.Dispose();
                }
                _memoryCache.Clear();
                
                // Clear disk cache
                if (Directory.Exists(_cacheDirectory))
                {
                    Directory.Delete(_cacheDirectory, true);
                    Directory.CreateDirectory(_cacheDirectory);
                    Console.WriteLine("🗑 Cache cleared");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error clearing cache: {ex.Message}");
            }
        }

        /// <summary>
        /// Add bitmap to memory cache with LRU eviction
        /// </summary>
        private void AddToMemoryCache(string key, Bitmap? bitmap)
        {
            if (bitmap == null) return;
            
            // If already exists, remove old one
            if (_memoryCache.ContainsKey(key))
            {
                _memoryCache[key].Dispose();
                _memoryCache.Remove(key);
            }
            
            // If cache is full, remove oldest item (LRU eviction)
            if (_memoryCache.Count >= MaxMemoryCacheItems)
            {
                var firstKey = _memoryCache.Keys.First();
                _memoryCache[firstKey].Dispose();
                _memoryCache.Remove(firstKey);
                Console.WriteLine($"🗑 Evicted oldest from memory cache");
            }
            
            _memoryCache.Add(key, bitmap);
            Console.WriteLine($"💾 Added to memory cache. Total items: {_memoryCache.Count}");
        }

        /// <summary>
        /// Cleanup old cache files if size exceeds limit (called on startup)
        /// </summary>
        private void CleanupOldCache()
        {
            try
            {
                var files = Directory.GetFiles(_cacheDirectory, "*");
                long totalSize = 0;
                var fileList = new List<(string Path, long Size, DateTime Modified)>();

                foreach (var file in files)
                {
                    if (file.EndsWith(".hash")) continue; // Skip hash files
                    
                    var fileInfo = new FileInfo(file);
                    totalSize += fileInfo.Length;
                    fileList.Add((file, fileInfo.Length, fileInfo.LastWriteTime));
                }

                // If size exceeds limit, delete oldest files
                if (totalSize > MaxCacheSizeBytes)
                {
                    var sortedFiles = fileList.OrderBy(f => f.Modified).ToList();
                    
                    foreach (var file in sortedFiles.Take(sortedFiles.Count / 2))
                    {
                        TryDeleteFile(file.Path);
                        TryDeleteFile(file.Path + ".hash");
                        Console.WriteLine($"🗑 Deleted old cache file: {Path.GetFileName(file.Path)}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Cache cleanup error: {ex.Message}");
            }
        }

        /// <summary>
        /// Get cache size in MB (disk only)
        /// </summary>
        public double GetCacheSizeMB()
        {
            try
            {
                var files = Directory.GetFiles(_cacheDirectory, "*");
                long totalSize = files.Sum(f => new FileInfo(f).Length);
                return (double)totalSize / 1024 / 1024;
            }
            catch
            {
                return 0;
            }
        }

        /// <summary>
        /// Get memory cache statistics
        /// </summary>
        public string GetMemoryCacheStats()
        {
            return $"Memory Cache: {_memoryCache.Count}/{MaxMemoryCacheItems} items";
        }

        private async Task<Bitmap?> DownloadAndSaveImageAsync(string url, string? serverHash, string cacheFilePath, string hashFilePath)
        {
            try
            {
                var imageData = await _httpClient.GetByteArrayAsync(url);
                
                using var ms = new MemoryStream(imageData);
                var bitmap = new Bitmap(ms);

                // Save to disk
                TryDeleteFile(cacheFilePath);
                bitmap.Save(cacheFilePath);

                // Save hash if provided
                if (!string.IsNullOrEmpty(serverHash))
                {
                    await File.WriteAllTextAsync(hashFilePath, serverHash);
                    Console.WriteLine($"💾 Hash saved: {serverHash}");
                }

                Console.WriteLine($"💾 Image saved to cache: {url}");
                return bitmap;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Download failed: {ex.Message}");
                return null;
            }
        }

        private Bitmap? LoadBitmapFromFile(string path)
        {
            try
            {
                return new Bitmap(path);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Failed to load bitmap: {ex.Message}");
                return null;
            }
        }

        private async Task<string?> ReadStoredHashAsync(string hashFilePath)
        {
            try
            {
                if (File.Exists(hashFilePath))
                {
                    return await File.ReadAllTextAsync(hashFilePath);
                }
                return null;
            }
            catch
            {
                return null;
            }
        }

        private void TryDeleteFile(string path)
        {
            try
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️ Failed to delete file {path}: {ex.Message}");
            }
        }

        private static string ComputeMD5(string input)
        {
            using var md5 = MD5.Create();
            var inputBytes = Encoding.UTF8.GetBytes(input);
            var hashBytes = md5.ComputeHash(inputBytes);
            
            var sb = new StringBuilder();
            foreach (var b in hashBytes)
            {
                sb.Append(b.ToString("x2"));
            }
            return sb.ToString();
        }
    }
}
