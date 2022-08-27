import Foundation
import IrohaCrypto
import SoraFoundation

final class LedgerTxConfirmPresenter: LedgerPerformOperationPresenter {
    let completion: TransactionSigningClosure

    private var expirationTimeInterval: TimeInterval?

    var wireframe: LedgerTxConfirmWireframeProtocol? {
        baseWireframe as? LedgerTxConfirmWireframeProtocol
    }

    var interactor: LedgerTxConfirmInteractorInputProtocol? {
        baseInteractor as? LedgerTxConfirmInteractorInputProtocol
    }

    private var timer = CountdownTimerMediator()

    var isExpired: Bool {
        expirationTimeInterval != nil &&
            timer.remainedInterval < TimeInterval.leastNonzeroMagnitude
    }

    init(
        chainName: String,
        interactor: LedgerTxConfirmInteractorInputProtocol,
        wireframe: LedgerTxConfirmWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.completion = completion

        super.init(
            chainName: chainName,
            baseInteractor: interactor,
            baseWireframe: wireframe,
            localizationManager: localizationManager
        )

        timer.addObserver(self)
    }

    private func performCancellation() {
        wireframe?.complete(on: view)

        completion(.failure(HardwareSigningError.signingCancelled))
    }

    private func handleInvalidData(reason: LedgerInvaliDataPolkadotReason) {
        switch reason {
        case let .unknown(reason):
            wireframe?.transitToInvalidData(on: view, reason: reason) { [weak self] in
                self?.performCancellation()
            }
        case .unsupportedOperation:
            wireframe?.transitToTransactionNotSupported(on: view) { [weak self] in
                self?.performCancellation()
            }
        case .outdatedMetadata:
            wireframe?.transitToMetadataOutdated(on: view, chainName: chainName) { [weak self] in
                self?.performCancellation()
            }
        }
    }

    override func handleAppConnection(error: Error, deviceId: UUID) {
        if let ledgerError = error as? LedgerError, case let .response(ledgerResponseError) = ledgerError {
            switch ledgerResponseError.code {
            case .transactionRejected:
                wireframe?.closeTransactionStatus(on: view)
            case .instructionNotSupported:
                wireframe?.transitToTransactionNotSupported(on: view) { [weak self] in
                    self?.performCancellation()
                }
            case .invalidData:
                if let reason = ledgerResponseError.reason() {
                    handleInvalidData(reason: LedgerInvaliDataPolkadotReason(rawReason: reason))
                } else {
                    wireframe?.closeTransactionStatus(on: view)
                    super.handleAppConnection(error: error, deviceId: deviceId)
                }
            default:
                wireframe?.closeTransactionStatus(on: view)
                super.handleAppConnection(error: error, deviceId: deviceId)
            }
        } else if
            let signatureError = error as? LedgerTxConfirmInteractorError,
            signatureError == .invalidSignature {
            wireframe?.transitToInvalidSignature(on: view) { [weak self] in
                self?.performCancellation()
            }
        } else {
            wireframe?.closeTransactionStatus(on: view)
            super.handleAppConnection(error: error, deviceId: deviceId)
        }
    }

    // MARK: Overriden

    override func selectDevice(at index: Int) {
        super.selectDevice(at: index)

        if let device = connectingDevice {
            wireframe?.transitToTransactionReview(on: view, timer: timer, deviceName: device.name) { [weak self] in
                self?.stopConnecting()
                self?.interactor?.cancelTransactionRequest(for: device.identifier)
            }
        }
    }
}

extension LedgerTxConfirmPresenter: LedgerTxConfirmPresenterProtocol {
    func cancel() {
        performCancellation()
    }
}

extension LedgerTxConfirmPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with _: TimeInterval) {
        if isExpired, let expirationTimeInterval = expirationTimeInterval {
            wireframe?.transitToTransactionExpired(
                on: view,
                expirationTimeInterval: expirationTimeInterval
            ) { [weak self] in
                self?.performCancellation()
            }
        }
    }
}

extension LedgerTxConfirmPresenter: LedgerTxConfirmInteractorOutputProtocol {
    func didReceiveSigning(result: Result<IRSignatureProtocol, Error>, for deviceId: UUID) {
        guard !isExpired else {
            // ignore any signing result if transaction is expired
            return
        }

        switch result {
        case let .success(signature):
            wireframe?.closeTransactionStatus(on: view)
            wireframe?.complete(on: view)
            completion(.success(signature))
        case let .failure(error):
            stopConnecting()

            handleAppConnection(error: error, deviceId: deviceId)
        }
    }

    func didReceiveTransactionExpiration(timeInterval: TimeInterval) {
        expirationTimeInterval = timeInterval

        timer.start(with: timeInterval)
    }
}
