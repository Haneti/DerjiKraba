using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media.Imaging;
using Avalonia.Platform.Storage;
using AvaloniaApplication1.ViewModels;

namespace AvaloniaApplication1.Views
{
    public partial class ProductsView : UserControl
    {
        public ProductsView()
        {
            InitializeComponent();
        }

        private async void PickImageButton_Click(object? sender, RoutedEventArgs e)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return;

            var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
            {
                Title = "Выберите изображение",
                AllowMultiple = false,
                FileTypeFilter = new[]
                {
                    new FilePickerFileType("Изображения")
                    {
                        Patterns = new[] { "*.jpg", "*.jpeg", "*.png", "*.webp" },
                        MimeTypes = new[] { "image/jpeg", "image/png", "image/webp" }
                    }
                }
            });

            if (files.Count == 0) return;

            var file = files[0];
            var path = file.TryGetLocalPath();
            if (path == null) return;

            if (DataContext is ProductsViewModel vm)
            {
                vm.PendingImagePath = path;
                vm.CurrentImageUrl = null;

                if (LocalPreviewImage != null)
                {
                    try { LocalPreviewImage.Source = new Bitmap(path); }
                    catch { LocalPreviewImage.Source = null; }
                }
            }
        }
    }
}
