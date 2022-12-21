import Foundation
import SoraFoundation
import UIKit

final class ReceivePresenter {
    weak var view: ReceiveViewProtocol?
    let wireframe: ReceiveWireframeProtocol
    let interactor: ReceiveInteractorInputProtocol
    let viewModelFactory: WalletAccountViewModelFactoryProtocol
    let accountShareFactory: NovaAccountShareFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    let logger: LoggerProtocol?

    private var qrCodeInfo: QRCodeInfo?
    private var account: MetaChainAccountResponse?
    private var chain: ChainModel?

    init(
        interactor: ReceiveInteractorInputProtocol,
        wireframe: ReceiveWireframeProtocol,
        viewModelFactory: WalletAccountViewModelFactoryProtocol,
        accountShareFactory: NovaAccountShareFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.accountShareFactory = accountShareFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension ReceivePresenter: ReceivePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func set(qrCodeSize: CGSize) {
        interactor.set(qrCodeSize: qrCodeSize)
    }

    func share() {
        guard let qrCodeInfo = qrCodeInfo else {
            return
        }
        let sharingItems = accountShareFactory.createSources(
            for: qrCodeInfo.encodingData,
            qrImage: qrCodeInfo.image
        )

        wireframe.share(
            items: sharingItems,
            from: view,
            with: nil
        )
    }

    func presentAccountOptions() {
        guard let view = view,
              let address = account?.chainAccount.toAddress(),
              let chain = chain else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: localizationManager.selectedLocale
        )
    }
}

extension ReceivePresenter: ReceiveInteractorOutputProtocol {
    func didReceive(
        account: MetaChainAccountResponse,
        chain: ChainModel,
        token: String
    ) {
        self.account = account
        self.chain = chain

        guard let accountModel = try? viewModelFactory.createViewModel(from: account) else {
            return
        }
        view?.didReceive(
            accountModel: accountModel,
            token: token
        )
    }

    func didReceive(qrCodeInfo: QRCodeInfo) {
        self.qrCodeInfo = qrCodeInfo
        view?.didReceive(qrImage: qrCodeInfo.image)
    }

    func didReceive(error: ReceiveInteractorError) {
        logger?.error(error.localizedDescription)
    }
}
