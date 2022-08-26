import Foundation
import IrohaCrypto
import SoraFoundation

final class LedgerTxConfirmPresenter: LedgerPerformOperationPresenter {
    let completion: TransactionSigningClosure

    private var expirationTimeInterval: TimeInterval?

    var wireframe: LedgerTxConfirmWireframeProtocol? {
        baseWireframe as? LedgerTxConfirmWireframeProtocol
    }

    private var timer = CountdownTimerMediator()

    var isExpired: Bool {
        expirationTimeInterval != nil &&
            timer.remainedInterval < TimeInterval.leastNonzeroMagnitude
    }

    init(
        chainName: String,
        interactor: LedgerPerformOperationInputProtocol,
        wireframe: LedgerTxConfirmWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.completion = completion

        super.init(
            chainName: chainName,
            interactor: interactor,
            baseWireframe: wireframe,
            localizationManager: localizationManager
        )

        timer.addObserver(self)
    }

    private func performCancellation() {
        wireframe?.complete(on: view)

        completion(.failure(HardwareSigningError.signingCancelled))
    }

    override func handleAppConnection(error: Error, deviceId: UUID) {
        if let ledgerError = error as? LedgerError, case let .response(code) = ledgerError {
            switch code {
            case .transactionRejected:
                wireframe?.closeTransactionStatus(on: view)
            case .instructionNotSupported:
                wireframe?.transitToTransactionNotSupported(on: view) { [weak self] in
                    self?.performCancellation()
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

        if isConnecting {
            wireframe?.transitToTransactionReview(on: view, timer: timer, deviceName: devices[index].name)
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
            stopConnecting(to: deviceId)

            handleAppConnection(error: error, deviceId: deviceId)
        }
    }

    func didReceiveTransactionExpiration(timeInterval: TimeInterval) {
        expirationTimeInterval = timeInterval

        timer.start(with: timeInterval)
    }
}
