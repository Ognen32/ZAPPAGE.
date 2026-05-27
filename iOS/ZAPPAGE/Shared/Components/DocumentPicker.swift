import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // CBZ is a ZIP with renamed extension; resolve its UTType dynamically.
        // Fall back to .data so the picker always opens even on unusual configurations.
        let cbz = UTType(filenameExtension: "cbz") ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [cbz])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Hard-filter: only pass through .cbz files regardless of what UTType resolved to
            guard let url = urls.first,
                  url.pathExtension.lowercased() == "cbz" else { return }
            onPick(url)
        }
    }
}
