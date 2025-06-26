import Foundation
import AVFoundation
import CoreImage

protocol QRCaptureServiceProtocol: AnyObject {
    var delegate: QRCaptureServiceDelegate? { get set }
    var delegateQueue: DispatchQueue { get set }

    func start()
    func stop()
}

enum QRCaptureServiceError: Error {
    case deviceAccessDeniedPreviously
    case deviceAccessDeniedNow
    case deviceAccessRestricted
    case unsupportedFormat
}

protocol QRCaptureServiceDelegate: AnyObject {
    func qrCapture(service: QRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession)
    func qrCapture(service: QRCaptureServiceProtocol, didReceive data: QRCodeData)
    func qrCapture(service: QRCaptureServiceProtocol, didFailure error: Error)
}

final class QRCaptureService: NSObject {
    static let processingQueue = DispatchQueue(label: "nova.qr.capture.service.queue")

    private(set) var captureSession: AVCaptureSession?

    weak var delegate: QRCaptureServiceDelegate?
    var delegateQueue: DispatchQueue

    init(
        delegate: QRCaptureServiceDelegate?,
        delegateQueue: DispatchQueue? = nil
    ) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue ?? QRCaptureService.processingQueue

        super.init()
    }

    private func configureSessionIfNeeded() throws {
        guard self.captureSession == nil else {
            return
        }

        let device = AVCaptureDevice.devices(for: .video).first { $0.position == .back }

        guard let camera = device else {
            throw QRCaptureServiceError.deviceAccessRestricted
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            throw QRCaptureServiceError.deviceAccessRestricted
        }

        let output = AVCaptureMetadataOutput()

        let captureSession = AVCaptureSession()
        captureSession.addInput(input)
        captureSession.addOutput(output)

        self.captureSession = captureSession

        output.setMetadataObjectsDelegate(self, queue: QRCaptureService.processingQueue)
        output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    }

    private func startAuthorizedSession() {
        QRCaptureService.processingQueue.async {
            do {
                try self.configureSessionIfNeeded()

                if let captureSession = self.captureSession {
                    captureSession.startRunning()

                    self.notifyDelegateWithCreation(of: captureSession)
                }
            } catch {
                self.notifyDelegate(with: error)
            }
        }
    }

    private func notifyDelegate(with error: Error) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didFailure: error)
        }
    }

    private func notifyDelegateWithCreation(of captureSession: AVCaptureSession) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didSetup: captureSession)
        }
    }

    private func notifyDelegateWithCode(_ code: QRCodeData) {
        run(in: delegateQueue) {
            self.delegate?.qrCapture(service: self, didReceive: code)
        }
    }

    private func run(in _: DispatchQueue, block: @escaping () -> Void) {
        if delegateQueue != QRCaptureService.processingQueue {
            delegateQueue.async {
                block()
            }
        } else {
            block()
        }
    }
}

extension QRCaptureService: QRCaptureServiceProtocol {
    public func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.startAuthorizedSession()
                } else {
                    self.notifyDelegate(with: QRCaptureServiceError.deviceAccessDeniedNow)
                }
            }
        case .denied:
            notifyDelegate(with: QRCaptureServiceError.deviceAccessDeniedPreviously)
        case .restricted:
            notifyDelegate(with: QRCaptureServiceError.deviceAccessRestricted)
        @unknown default:
            break
        }
    }

    func stop() {
        QRCaptureService.processingQueue.async {
            self.captureSession?.stopRunning()
        }
    }
}

extension QRCaptureService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }

        if let possibleCode = metadata.stringValue {
            notifyDelegateWithCode(.plain(possibleCode))
        } else if let descriptor = metadata.descriptor as? CIQRCodeDescriptor {
            if let data = try? descriptor.errorCorrectedPayload.extractBytePayload(for: 10) {
                notifyDelegateWithCode(.raw(data))
            } else {
                notifyDelegate(with: QRCaptureServiceError.unsupportedFormat)
            }
        } else {
            notifyDelegate(with: QRCaptureServiceError.unsupportedFormat)
        }
    }
}
