import Foundation
import AVFoundation
import SwiftUI

// MARK: - Camera Service (iOS only)

#if os(iOS)

@Observable
class CameraService {
    let session = AVCaptureSession()
    var isAuthorized = false
    var permissionDenied = false

    private let sessionQueue = DispatchQueue(label: "com.cortisoltracker.camera")

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            if !isAuthorized { permissionDenied = true }
        default:
            isAuthorized = false
            permissionDenied = true
        }

        guard isAuthorized else { return }

        sessionQueue.async { [weak self] in
            self?.configureAndStart()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndStart() {
        guard !session.isRunning else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )

        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.commitConfiguration()
        session.startRunning()
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

#endif
