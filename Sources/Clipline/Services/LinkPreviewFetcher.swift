import AppKit
import LinkPresentation

/// Loads a link's page title and preview image (Open Graph image, else the site icon).
enum LinkPreviewFetcher {
    static func fetch(_ url: URL, completion: @escaping (String?, NSImage?) -> Void) {
        let provider = LPMetadataProvider()
        provider.timeout = 10
        provider.startFetchingMetadata(for: url) { metadata, _ in
            _ = provider // keep the provider alive until the request finishes
            let title = metadata?.title
            guard let imageProvider = metadata?.imageProvider ?? metadata?.iconProvider,
                  imageProvider.canLoadObject(ofClass: NSImage.self) else {
                DispatchQueue.main.async { completion(title, nil) }
                return
            }
            imageProvider.loadObject(ofClass: NSImage.self) { object, _ in
                let image = object as? NSImage
                DispatchQueue.main.async { completion(title, image) }
            }
        }
    }
}
