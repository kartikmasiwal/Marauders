@preconcurrency import AVFoundation
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    enum State: Equatable { case checking, denied, unavailable, ready }

    @Published private(set) var state: State = .checking
    @Published private(set) var capturedImage: UIImage?
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in granted ? self?.configure() : self?.setDenied() }
            }
        case .denied, .restricted: state = .denied
        @unknown default: state = .denied
        }
    }

    func capture() {
        guard state == .ready else { return }
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func stop() {
        let session = session
        DispatchQueue.global(qos: .userInitiated).async { if session.isRunning { session.stopRunning() } }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        Task { @MainActor in self.capturedImage = image }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            state = .unavailable
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        state = .ready
        let session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func setDenied() { state = .denied }
}
