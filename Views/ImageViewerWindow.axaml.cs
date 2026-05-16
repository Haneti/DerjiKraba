using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using System;

namespace AvaloniaApplication1.Views
{
    public partial class ImageViewerWindow : Window
    {
        private double _currentZoom = 1.0;
        private const double ZoomStep = 0.1;
        private const double MinZoom = 0.1;
        private const double MaxZoom = 5.0;
        private bool _isDragging;
        private Point _lastMousePosition;
        private ScaleTransform? _scaleTransform;

        public ImageViewerWindow()
        {
            InitializeComponent();
            
            KeyDown += OnKeyDown;
            PointerPressed += OnPointerPressed;
            PointerReleased += OnPointerReleased;
            PointerMoved += OnPointerMoved;
            
            // Use tunneling strategy to capture wheel events before ScrollViewer
            AddHandler(PointerWheelChangedEvent, OnPreviewPointerWheelChanged, Avalonia.Interactivity.RoutingStrategies.Tunnel);
        }

        private void OnPreviewPointerWheelChanged(object? sender, PointerWheelEventArgs e)
        {
            if (e.KeyModifiers == KeyModifiers.Control)
            {
                HandleZoom(e);
                e.Handled = true;
            }
        }

        public void SetImage(Bitmap bitmap)
        {
            if (ViewerImage != null)
            {
                ViewerImage.Source = bitmap;
                // Create new scale transform
                _scaleTransform = new ScaleTransform(1.0, 1.0);
                ViewerImage.RenderTransform = _scaleTransform;
            }
            ResetZoom();
        }

        private void ResetZoom()
        {
            _currentZoom = 1.0;
            UpdateZoom();
        }

        private void UpdateZoom()
        {
            if (_scaleTransform != null)
            {
                _scaleTransform.ScaleX = _currentZoom;
                _scaleTransform.ScaleY = _currentZoom;
            }
            if (ZoomInfo != null)
                ZoomInfo.Text = $"{(_currentZoom * 100):0}%";
        }

        private void OnPointerWheelChanged(object? sender, PointerWheelEventArgs e)
        {
            HandleZoom(e);
        }

        private void OnGridPointerWheelChanged(object? sender, PointerWheelEventArgs e)
        {
            HandleZoom(e);
        }

        private void OnScrollViewerPointerWheelChanged(object? sender, PointerWheelEventArgs e)
        {
            // Handle zoom on ScrollViewer, but only if Ctrl is pressed
            if (e.KeyModifiers == KeyModifiers.Control)
            {
                HandleZoom(e);
                e.Handled = true; // Prevent scrolling
            }
        }

        private void HandleZoom(PointerWheelEventArgs e)
        {
            if (e.KeyModifiers == KeyModifiers.Control)
            {
                if (e.Delta.Y > 0)
                    _currentZoom = Math.Min(_currentZoom + ZoomStep, MaxZoom);
                else
                    _currentZoom = Math.Max(_currentZoom - ZoomStep, MinZoom);
                UpdateZoom();
                e.Handled = true;
            }
        }

        private void OnPointerPressed(object? sender, PointerPressedEventArgs e)
        {
            if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed && ImageScrollViewer != null)
            {
                _isDragging = true;
                _lastMousePosition = e.GetPosition(ImageScrollViewer);
                e.Handled = true;
            }
        }

        private void OnPointerReleased(object? sender, PointerReleasedEventArgs e)
        {
            _isDragging = false;
        }

        private void OnPointerMoved(object? sender, PointerEventArgs e)
        {
            if (_isDragging && ImageScrollViewer != null && ViewerImage?.Source != null)
            {
                var currentPosition = e.GetPosition(ImageScrollViewer);
                var offsetX = _lastMousePosition.X - currentPosition.X;
                var offsetY = _lastMousePosition.Y - currentPosition.Y;

                // Calculate new offset with bounds checking
                var newOffsetX = ImageScrollViewer.Offset.X + offsetX;
                var newOffsetY = ImageScrollViewer.Offset.Y + offsetY;

                // Get image and viewport dimensions
                var imageWidth = ViewerImage.Source.Size.Width * _currentZoom;
                var imageHeight = ViewerImage.Source.Size.Height * _currentZoom;
                var viewportWidth = ImageScrollViewer.Viewport.Width;
                var viewportHeight = ImageScrollViewer.Viewport.Height;

                // Clamp offsets so the image cannot be dragged outside the viewport
                var maxOffsetX = Math.Max(0, imageWidth - viewportWidth);
                var maxOffsetY = Math.Max(0, imageHeight - viewportHeight);

                newOffsetX = Math.Clamp(newOffsetX, 0, maxOffsetX);
                newOffsetY = Math.Clamp(newOffsetY, 0, maxOffsetY);

                ImageScrollViewer.Offset = new Vector(newOffsetX, newOffsetY);
                _lastMousePosition = currentPosition;
                e.Handled = true;
            }
        }

        private void OnKeyDown(object? sender, KeyEventArgs e)
        {
            if (e.Key == Key.Escape)
                Close();
        }

        private void CloseButton_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        {
            Close();
        }
    }
}
