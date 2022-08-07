import Foundation
import UIKit
import SoraFoundation

final class ParitySignerTxQrPresenter {
    weak var view: ParitySignerTxQrViewProtocol?
    let wireframe: ParitySignerTxQrWireframeProtocol
    let interactor: ParitySignerTxQrInteractorInputProtocol
    let logger: LoggerProtocol
    let completion: TransactionSigningClosure

    private var transactionCode: TransactionDisplayCode?
    private var wallet: ChainWalletDisplayAddress?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()

    init(
        interactor: ParitySignerTxQrInteractorInputProtocol,
        wireframe: ParitySignerTxQrWireframeProtocol,
        completion: @escaping TransactionSigningClosure,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.completion = completion
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

    private func updateExpirationTimer() {}
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

    func activateTroubleshouting() {}

    func proceed() {}
}

extension ParitySignerTxQrPresenter: ParitySignerTxQrInteractorOutputProtocol {
    func didReceive(chainWallet: ChainWalletDisplayAddress) {
        wallet = chainWallet

        provideWalletViewModel()
    }

    func didReceive(transactionCode: TransactionDisplayCode) {
        self.transactionCode = transactionCode

        provideCodeViewModel()
        updateExpirationTimer()
    }

    func didReceive(error: Error) {
        handle(error: error)
    }
}

extension ParitySignerTxQrPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {}
    }
}
