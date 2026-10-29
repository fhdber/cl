import AppKit
import AVFoundation
import Combine
import SwiftUI

/// Front camera "mirror". Runs only while the widget shows it and stops when the shelf closes.
final class CameraMirror: ObservableObject {
    static let shared = CameraMirror()

    let session = AVCaptureSession()
    @Published private(set) var isRunning = false
    @Published private(set) var denied = false
    /// The camera permission dialog is up. It takes focus, but the shelf must stay open meanwhile.
    @Published private(set) var isRequestingAccess = false

    private let queue = DispatchQueue(label: "clipline.camera")
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            isRequestingAccess = true
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isRequestingAccess = false
                    if granted { self.run() } else { self.denied = true }
                }
            }
        default:
            denied = true
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        queue.async { self.session.stopRunning() }
    }

    private func run() {
        isRunning = true
        queue.async {
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium
                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            self.session.startRunning()
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewHostView { PreviewHostView(session: session) }
    func updateNSView(_ view: PreviewHostView, context: Context) {}

    /// The preview layer *is* the view's backing layer, so AppKit keeps it exactly the view's size.
    /// macOS already mirrors the front camera in previews, so no extra flip is needed.
    final class PreviewHostView: NSView {
        private let session: AVCaptureSession

        init(session: AVCaptureSession) {
            self.session = session
            super.init(frame: .zero)
            wantsLayer = true
        }

        required init?(coder: NSCoder) { nil }

        override func makeBackingLayer() -> CALayer {
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            return preview
        }
    }
}
