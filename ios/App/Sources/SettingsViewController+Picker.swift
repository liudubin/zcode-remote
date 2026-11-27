import PhotosUI
import UIKit
import WebKit
extension SettingsViewController: PHPickerViewControllerDelegate {
    func presentWallpaperPicker() {
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
        item.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self, let image = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self.settings.saveWallpaper(image)
                self.tableView.reloadData()
                self.onChange()
            }
        }
    }
}

