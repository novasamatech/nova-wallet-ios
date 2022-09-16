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

    override func handleAppConnection(error: Error, deviceId: UUID) {
        guard let view = view else {
            return
        }

        if let ledgerError = error as? LedgerError {
            wireframe?.presentLedgerError(
                on: view,
                error: ledgerError,
                networkName: chainName,
                cancelClosure: { [weak self] in
                    self?.performCancellation()
                },
                retryClosure: { [weak self] in
                    guard let index = self?.devices.firstIndex(where: { $0.identifier == deviceId }) else {
                        return
                    }

                    self?.selectDevice(at: index)
                }
            )
        } else if
            let signatureError = error as? LedgerTxConfirmInteractorError,
            signatureError == .invalidSignature {
            wireframe?.transitToInvalidSignature(on: view) { [weak self] in
                self?.performCancellation()
            }
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
            guard let view = view else {
                return
            }

            wireframe?.closeMessageSheet(on: view)
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
