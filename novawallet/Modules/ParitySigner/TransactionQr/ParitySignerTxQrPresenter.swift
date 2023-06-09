import Foundation
import UIKit
import SoraFoundation

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
    private var wallet: ChainWalletDisplayAddress?
    private var timer = CountdownTimerMediator()

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

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
        guard let wallet = wallet else {
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
        guard let transactionCode = transactionCode else {
            return
        }

        view?.didReceiveCode(viewModel: transactionCode.image)
    }

    private func updateExpirationViewModel() {
        guard transactionCode != nil else {
            return
        }

        do {
            let viewModel = try expirationViewModelFactory.createViewModel(from: timer.remainedInterval)
            view?.didReceiveExpiration(viewModel: viewModel)
        } catch {
            handle(error: error)
        }
    }

    private func applyNewExpirationInterval(after oldExpirationInterval: TimeInterval?) {
        let remainedTimeInterval = timer.remainedInterval

        clearTimer()

        guard let transactionCode = transactionCode else {
            return
        }

        if
            let oldExpirationInterval = oldExpirationInterval, oldExpirationInterval >= remainedTimeInterval {
            let elapsedTime = oldExpirationInterval - remainedTimeInterval
            let newTimerInterval = max(transactionCode.expirationTime - elapsedTime, 0.0)

            setupTimer(for: newTimerInterval)
        } else {
            setupTimer(for: transactionCode.expirationTime)
        }
    }

    private func clearTimer() {
        timer.removeObserver(self)
        timer.stop()
    }

    private func setupTimer(for timeInterval: TimeInterval) {
        timer.addObserver(self)
        timer.start(with: timeInterval)
    }

    private func presentQrExpiredAlert() {
        guard let view = view else {
            return
        }

        let expirationTimeInterval = transactionCode?.expirationTime.minutesFromSeconds

        wireframe.presentTransactionExpired(
            on: view,
            typeName: type.getName(for: selectedLocale),
            validInMinutes: expirationTimeInterval,
            locale: selectedLocale
        ) { [weak self] in
            self?.wireframe.close(view: self?.view)
            self?.completion(.failure(HardwareSigningError.signingCancelled))
        }
    }
}

extension ParitySignerTxQrPresenter: ParitySignerTxQrPresenterProtocol {
    func setup(qrSize: CGSize) {
        interactor.setup(qrSize: qrSize)
    }

    func activateAddressDetails() {
        guard let wallet = wallet, let view = view else {
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

    func proceed() {
        guard
            transactionCode != nil,
            let accountId = try? wallet?.walletDisplayAddress.address.toAccountId() else {
            return
        }

        wireframe.proceed(
            from: view,
            accountId: accountId,
            type: type,
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
    func didReceive(chainWallet: ChainWalletDisplayAddress) {
        wallet = chainWallet

        provideWalletViewModel()
    }

    func didReceive(transactionCode: TransactionDisplayCode) {
        let currentExpirationInterval = self.transactionCode?.expirationTime
        self.transactionCode = transactionCode

        provideCodeViewModel()
        applyNewExpirationInterval(after: currentExpirationInterval)
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

        if timer.remainedInterval < TimeInterval.leastNonzeroMagnitude, transactionCode?.expirationTime != nil {
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
