import Foundation
import UIKit
import Foundation_iOS

final class ParitySignerTxQrPresenter {
    weak var view: ParitySignerTxQrViewProtocol?
    let wireframe: ParitySignerTxQrWireframeProtocol
    let interactor: ParitySignerTxQrInteractorInputProtocol
    let logger: LoggerProtocol
    let completion: TransactionSigningClosure
    let expirationViewModelFactory: ExpirationViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let type: ParitySignerType

    private var transactionCode: TransactionDisplayCode?
    private var model: ParitySignerTxQrSetupModel?
    private var qrFormat: ParitySignerQRFormat?
    private var qrSize: CGSize?
    private var timer: CountdownTimerMediator?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var qrImageViewModelFactory = QRImageViewModelFactory()

    init(
        type: ParitySignerType,
        interactor: ParitySignerTxQrInteractorInputProtocol,
        wireframe: ParitySignerTxQrWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        expirationViewModelFactory: ExpirationViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.type = type
        self.interactor = interactor
        self.wireframe = wireframe
        self.completion = completion
        self.expirationViewModelFactory = expirationViewModelFactory
        self.applicationConfig = applicationConfig
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func handle(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        logger.error("Did receive error: \(error)")
    }

    private func provideWalletViewModel() {
        guard let wallet = model?.chainWallet else {
            return
        }

        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: wallet.walletDisplayAddress)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            handle(error: error)
        }
    }

    private func provideCodeViewModel() {
        if
            let transactionCode,
            let viewModel = qrImageViewModelFactory.createViewModel(from: transactionCode.images) {
            view?.didReceiveCode(viewModel: viewModel)
        } else {
            view?.didReceiveCode(viewModel: nil)
        }
    }

    private func provideQrFormatViewModel() {
        guard let preferredFormats = model?.preferredFormats, let qrFormat else {
            view?.didReceiveQrFormat(viewModel: .none)
            return
        }

        let canSwitchFormats = preferredFormats.contains(.extrinsicWithProof) &&
            preferredFormats.contains(.extrinsicWithoutProof)

        if canSwitchFormats {
            switch qrFormat {
            case .extrinsicWithProof:
                view?.didReceiveQrFormat(viewModel: .new)
            case .extrinsicWithoutProof:
                view?.didReceiveQrFormat(viewModel: .legacy)
            case .rawBytes:
                view?.didReceiveQrFormat(viewModel: .none)
            }
        } else {
            view?.didReceiveQrFormat(viewModel: .none)
        }
    }

    private func updateExpirationViewModel() {
        guard let timer else {
            view?.didReceiveExpiration(viewModel: nil)
            return
        }

        do {
            let viewModel = try expirationViewModelFactory.createViewModel(from: timer.remainedInterval)
            view?.didReceiveExpiration(viewModel: viewModel)
        } catch {
            handle(error: error)
        }
    }

    private func applyNewExpirationInterval() {
        clearTimer()

        guard let expirationTime = model?.txExpirationTime else {
            return
        }

        setupTimer(for: expirationTime)
    }

    private func clearTimer() {
        timer?.removeObserver(self)
        timer?.stop()
        timer = nil
    }

    private func setupTimer(for timeInterval: TimeInterval) {
        let timer = CountdownTimerMediator()
        self.timer = timer

        timer.addObserver(self)
        timer.start(with: timeInterval)
    }

    private func presentQrExpiredAlert() {
        guard let expirationTime = model?.txExpirationTime, let view else {
            return
        }

        wireframe.presentTransactionExpired(
            on: view,
            typeName: type.getName(for: selectedLocale),
            validInMinutes: expirationTime.minutesFromSeconds,
            locale: selectedLocale
        ) { [weak self] in
            self?.wireframe.close(view: self?.view)
            self?.completion(.failure(HardwareSigningError.signingCancelled))
        }
    }

    private func refreshQrCode() {
        guard let qrFormat, let qrSize else {
            return
        }

        transactionCode = nil
        provideCodeViewModel()

        interactor.generateQr(with: qrFormat, qrSize: qrSize)
    }
}

extension ParitySignerTxQrPresenter: ParitySignerTxQrPresenterProtocol {
    func setup(qrSize: CGSize) {
        self.qrSize = qrSize

        provideQrFormatViewModel()

        interactor.setup()
    }

    func activateAddressDetails() {
        guard let wallet = model?.chainWallet, let view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: wallet.walletDisplayAddress.address,
            chain: wallet.chain,
            locale: selectedLocale
        )
    }

    func activateTroubleshouting() {
        guard let view = view else {
            return
        }

        wireframe.showWeb(
            url: type.getTroubleshootingUrl(for: applicationConfig),
            from: view,
            style: .automatic
        )
    }

    func toggleExtrinsicFormat() {
        switch qrFormat {
        case .extrinsicWithProof:
            qrFormat = .extrinsicWithoutProof
            refreshQrCode()
        case .extrinsicWithoutProof:
            qrFormat = .extrinsicWithProof
            refreshQrCode()
        case nil, .rawBytes:
            break
        }
    }

    func proceed() {
        guard
            transactionCode != nil,
            let verificationModel = model?.verificationModel else {
            return
        }

        wireframe.proceed(
            from: view,
            verificationModel: verificationModel,
            timer: timer,
            completion: completion
        )
    }

    func close() {
        wireframe.close(view: view)

        completion(.failure(HardwareSigningError.signingCancelled))
    }
}

extension ParitySignerTxQrPresenter: ParitySignerTxQrInteractorOutputProtocol {
    func didCompleteSetup(model: ParitySignerTxQrSetupModel) {
        self.model = model
        qrFormat = model.preferredFormats.first

        provideWalletViewModel()
        provideQrFormatViewModel()
        applyNewExpirationInterval()

        refreshQrCode()
    }

    func didReceive(transactionCode: TransactionDisplayCode) {
        self.transactionCode = transactionCode

        provideCodeViewModel()
    }

    func didReceive(error: Error) {
        handle(error: error)
    }
}

extension ParitySignerTxQrPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateExpirationViewModel()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateExpirationViewModel()
    }

    func didStop(with _: TimeInterval) {
        updateExpirationViewModel()

        if let timer, timer.remainedInterval < TimeInterval.leastNonzeroMagnitude {
            presentQrExpiredAlert()
        }
    }
}

extension ParitySignerTxQrPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateExpirationViewModel()
        }
    }
}
