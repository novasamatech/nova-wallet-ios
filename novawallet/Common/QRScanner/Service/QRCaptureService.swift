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
            if let data = payloadData(from: descriptor) {
                notifyDelegateWithCode(.raw(data))
            } else {
                notifyDelegate(with: QRCaptureServiceError.unsupportedFormat)
            }

        } else {
            notifyDelegate(with: QRCaptureServiceError.unsupportedFormat)
        }
    }

    // TODO: Refactor this
    func payloadData(from qr: CIQRCodeDescriptor) -> Data? {
        let bytes = [UInt8](qr.errorCorrectedPayload)
        guard !bytes.isEmpty else { return nil }

        // --- 1. Decode header -------------------------------------------------
        // First 4 bits: mode. In Byte mode they are 0b0100 (= 0x4)
        let mode = bytes[0] >> 4
        guard mode == 0b0100 else { return nil }

        // Character-count indicator: 8 bits for version 1-9.
        // They start in the low nibble of byte 0 and finish in the high nibble of byte 1.
        let length = Int(((bytes[0] & 0x0F) << 4) | (bytes[1] >> 4))

        // --- 2. Extract message ----------------------------------------------
        // Message starts at bit offset 12 (4 for mode + 8 for length),
        // i.e. byte offset 1, bit offset 4.
        var result = [UInt8]()
        var bitIndex = 12 // current read position
        func readBit() -> UInt8 {
            let byte = bytes[bitIndex / 8]
            let bit = 7 - (bitIndex % 8)
            bitIndex += 1
            return (byte >> bit) & 1
        }
        func readByte() -> UInt8 {
            (0 ..< 8).reduce(0) { acc, _ in (acc << 1) | readBit() }
        }

        for _ in 0 ..< length {
            result.append(readByte())
        }
        return Data(result)
    }
}
