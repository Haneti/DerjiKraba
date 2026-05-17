using Avalonia.Controls;
using AvaloniaApplication1.ViewModels;

namespace AvaloniaApplication1.Views
{
    /// <summary>
    /// View для очистки кэша изображений
    /// </summary>
    public partial class ImageCacheCleanupView : UserControl
    {
        public ImageCacheCleanupView()
        {
            InitializeComponent();
            DataContext = new ImageCacheCleanupViewModel();
        }
    }
}
