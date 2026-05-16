using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media.Imaging;
using AvaloniaApplication1.Controls;
using System;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

namespace AvaloniaApplication1.Views
{
    public partial class SupportView : UserControl
    {
        private static ImageViewerWindow? _imageViewerInstance;
        public SupportView()
        {
            InitializeComponent();
            DataContextChanged += OnDataContextChanged;
        }

        private void OnDataContextChanged(object? sender, EventArgs e)
        {
            // Auto-scroll to bottom when messages change
            if (MessagesItemsControl != null)
            {
                MessagesItemsControl.PropertyChanged += (s, args) =>
                {
                    if (args.Property.Name == nameof(ItemsControl.ItemsSource))
                    {
                        ScrollToBottom();
                    }
                };
            }
        }

        private void ScrollToBottom()
        {
            if (MessagesScrollViewer != null)
            {
                // Delay to allow layout to update
                Task.Delay(100).ContinueWith(_ =>
                {
                    Avalonia.Threading.Dispatcher.UIThread.Post(() =>
                    {
                        MessagesScrollViewer.ScrollToEnd();
                    });
                });
            }
        }

        private async void OnImagePointerPressed(object? sender, PointerPressedEventArgs e)
        {
            if (sender is Border border && border.Tag is string imageUrl)
            {
                await OpenImageViewer(imageUrl);
            }
        }

        private void OnMessageTextBoxKeyDown(object? sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter && DataContext is ViewModels.SupportViewModel vm)
            {
                // Trigger send message command
                if (vm.SendMessageCommand.CanExecute(null))
                {
                    vm.SendMessageCommand.Execute(null);
                }
                e.Handled = true;
            }
        }

        private async Task OpenImageViewer(string imageUrl)
        {
            try
            {
                using var httpClient = new HttpClient();
                var bytes = await httpClient.GetByteArrayAsync(imageUrl);

                using var stream = new MemoryStream(bytes);
                var bitmap = new Bitmap(stream);

                if (_imageViewerInstance == null || !_imageViewerInstance.IsVisible)
                {
                    _imageViewerInstance = new ImageViewerWindow();
                    _imageViewerInstance.Closed += (_, _) => _imageViewerInstance = null;
                    _imageViewerInstance.SetImage(bitmap);
                    _imageViewerInstance.Show();
                }
                else
                {
                    _imageViewerInstance.SetImage(bitmap);
                    _imageViewerInstance.Activate();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Error opening image: {ex.Message}");
            }
        }
    }
}
