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

    private let queue = DispatchQueue(label: "clipline.camera")
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
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

    final class PreviewHostView: NSView {
        private let preview: AVCaptureVideoPreviewLayer

        init(session: AVCaptureSession) {
            preview = AVCaptureVideoPreviewLayer(session: session)
            super.init(frame: .zero)
            wantsLayer = true
            preview.videoGravity = .resizeAspectFill
            preview.transform = CATransform3DMakeScale(-1, 1, 1) // mirror, like a real mirror
            layer?.addSublayer(preview)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            preview.frame = bounds
            CATransaction.commit()
        }
    }
}
