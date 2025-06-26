import Foundation
import Foundation_iOS
import RaptorQ_iOS

final class ParitySignerScanPresenter: QRScannerPresenter {
    let interactor: ParitySignerScanInteractorInputProtocol

    let matcher: ParitySignerScanMatcherProtocol
    let qrExtractionError: LocalizableResource<String>

    let localizationManager: LocalizationManagerProtocol

    let scanWireframe: ParitySignerScanWireframeProtocol

    let type: ParitySignerType

    private var lastHandledCode: QRCodeData?

    private var decoder: RaptorQDecoder?
    private var processedFrames = Set<Data>()

    private var mutex = NSLock()

    init(
        type: ParitySignerType,
        matcher: ParitySignerScanMatcherProtocol,
        interactor: ParitySignerScanInteractorInputProtocol,
        scanWireframe: ParitySignerScanWireframeProtocol,
        baseWireframe: QRScannerWireframeProtocol,
        qrScanService: QRCaptureServiceProtocol,
        qrExtractionService: QRExtractionServiceProtocol,
        qrExtractionError: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.type = type
        self.matcher = matcher
        self.interactor = interactor
        self.scanWireframe = scanWireframe
        self.qrExtractionError = qrExtractionError
        self.localizationManager = localizationManager

        super.init(
            wireframe: baseWireframe,
            qrScanService: qrScanService,
            qrExtractionService: qrExtractionService,
            logger: logger
        )
    }

    private func getLastCode() -> QRCodeData? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return lastHandledCode
    }

    private func setLastCode(_ newCode: QRCodeData?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        lastHandledCode = newCode
    }

    private func handleFailure() {
        let locale = localizationManager.selectedLocale
        let message = qrExtractionError.value(for: locale)
        view?.present(message: message, animated: true)
    }

    private func handle(code: QRCodeData) {
        guard getLastCode() != code else {
            return
        }

        setLastCode(code)

        if let walletUpdate = matcher.match(code: code) {
            DispatchQueue.main.async { [weak self] in
                self?.interactor.process(walletUpdate: walletUpdate)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleFailure()
            }
        }
    }

    override func handle(plainTextCode: String) {
        handle(code: QRCodeData.plain(plainTextCode))
    }

    override func handle(rawDataCode: Data) {
        guard !processedFrames.contains(rawDataCode) else {
            return
        }

        guard let frame = RaptorQFrame(payload: rawDataCode) else {
            logger?.warning("Not a raptor frame")
            return
        }

        if let decoder {
            if decoder.push(frame: frame.packet) {
                logger?.debug("Processed raptor frame")
                processedFrames.insert(rawDataCode)
            }
        } else if let newDecoder = RaptorQDecoder(
            totalBytes: UInt64(frame.totalLength),
            maxPayload: UInt16(frame.packet.count)
        ) {
            logger?.debug("New Raptor decoder")
            decoder = newDecoder

            handle(rawDataCode: rawDataCode)
        } else {
            logger?.warning("Can't raptor handle data")
        }

        guard let decoder, decoder.isComplete else {
            return
        }

        logger?.debug("Raptor parsing completed")

        if let data = decoder.takeResult() {
            handle(code: .raw(data))
        } else {
            logger?.warning("No data result after completing raptor decoding")
        }

        processedFrames.removeAll()
        self.decoder = nil
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        setLastCode(nil)
    }
}

extension ParitySignerScanPresenter: ParitySignerScanInteractorOutputProtocol {
    func didReceiveValidation(result: Result<PolkadotVaultWalletUpdate, Error>) {
        switch result {
        case let .success(update):
            scanWireframe.completeScan(on: view, walletUpdate: update, type: type)
        case .failure:
            handleFailure()
            setLastCode(nil)
        }
    }
}
