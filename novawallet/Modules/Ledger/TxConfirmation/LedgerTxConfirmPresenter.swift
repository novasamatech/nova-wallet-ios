import Foundation
import NovaCrypto
import Foundation_iOS

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

    let needsMigration: Bool
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol

    init(
        chainName: String,
        needsMigration: Bool,
        applicationConfig: ApplicationConfigProtocol,
        interactor: LedgerTxConfirmInteractorInputProtocol,
        wireframe: LedgerTxConfirmWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.completion = completion
        self.needsMigration = needsMigration
        self.applicationConfig = applicationConfig
        self.logger = logger

        super.init(
            appName: chainName,
            baseInteractor: interactor,
            baseWireframe: wireframe,
            localizationManager: localizationManager
        )

        timer.addObserver(self)
    }

    private func createMigrationWillBeUnavailableIfNeeded() -> MessageSheetMigrationBannerView.ContentViewModel? {
        guard needsMigration else {
            return nil
        }

        return LocalizableResource { locale in
            MessageSheetMigrationBannerView.ViewModel.createLedgerMigrationWillBeUnavailable(
                for: locale
            ) { [weak self] in
                self?.activateMigrationPage()
            }
        }
    }

    private func createMigrationDownloadIfNeeded() -> MessageSheetMigrationBannerView.ContentViewModel? {
        guard needsMigration else {
            return nil
        }

        return LocalizableResource { locale in
            MessageSheetMigrationBannerView.ViewModel.createLedgerMigrationDownload(
                for: locale
            ) { [weak self] in
                self?.activateMigrationPage()
            }
        }
    }

    private func createMigrationIfNeeded(
        for error: LedgerError
    ) -> MessageSheetMigrationBannerView.ContentViewModel? {
        if
            case let .response(responseError) = error,
            responseError.isValidAppNotOpen() {
            return createMigrationDownloadIfNeeded()
        } else {
            return createMigrationWillBeUnavailableIfNeeded()
        }
    }

    private func activateMigrationPage() {
        guard let view else {
            return
        }

        if let connectingDevice {
            interactor?.cancelTransactionRequest(for: connectingDevice.identifier)
            stopConnecting()
        }

        wireframe?.closeMessageSheet(on: view)

        wireframe?.showWeb(
            url: applicationConfig.ledgerMigrationURL,
            from: view,
            style: .automatic
        )
    }

    private func performCancellation() {
        wireframe?.complete(on: view) {
            self.completion(.failure(HardwareSigningError.signingCancelled))
        }
    }

    override func handleAppConnection(error: Error, deviceId: UUID) {
        guard
            let view,
            let device = devices.first(where: { $0.identifier == deviceId })
        else { return }

        if let ledgerError = error as? LedgerError {
            wireframe?.presentLedgerError(
                on: view,
                error: ledgerError,
                context: LedgerErrorPresentableContext(
                    networkName: appName,
                    deviceModel: device.model,
                    migrationViewModel: createMigrationIfNeeded(for: ledgerError)
                ),
                callbacks: LedgerErrorPresentableCallbacks(
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
            )
        } else if
            let signatureError = error as? LedgerTxConfirmInteractorError,
            signatureError == .invalidSignature {
            wireframe?.transitToInvalidSignature(
                on: view,
                deviceModel: device.model,
                migrationViewModel: createMigrationWillBeUnavailableIfNeeded()
            ) { [weak self] in
                self?.performCancellation()
            }
        }
    }

    // MARK: Overriden

    override func selectDevice(at index: Int) {
        super.selectDevice(at: index)

        if let device = connectingDevice {
            wireframe?.transitToTransactionReview(
                on: view,
                timer: timer,
                deviceInfo: device.deviceInfo,
                migrationViewModel: createMigrationWillBeUnavailableIfNeeded()
            ) { [weak self] in
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
                expirationTimeInterval: expirationTimeInterval,
                deviceModel: connectingDevice?.model ?? .unknown,
                migrationViewModel: createMigrationWillBeUnavailableIfNeeded()
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
            wireframe?.complete(on: view) {
                self.completion(.success(signature))
            }
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            stopConnecting()

            handleAppConnection(error: error, deviceId: deviceId)
        }
    }

    func didReceiveTransactionExpiration(timeInterval: TimeInterval) {
        expirationTimeInterval = timeInterval

        timer.start(with: timeInterval)
    }
}
