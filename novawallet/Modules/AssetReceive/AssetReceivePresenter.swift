import Foundation
import SoraFoundation
import SubstrateSdk
import UIKit

final class AssetReceivePresenter {
    weak var view: AssetReceiveViewProtocol?
    let wireframe: AssetReceiveWireframeProtocol
    let interactor: AssetReceiveInteractorInputProtocol
    let iconGenerator: IconGenerating
    let accountShareFactory: NovaAccountShareFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    let logger: LoggerProtocol?

    private var qrCodeInfo: QRCodeInfo?
    private var account: MetaChainAccountResponse?
    private var chain: ChainModel?
    private var qrCodeSize: CGSize?

    init(
        interactor: AssetReceiveInteractorInputProtocol,
        wireframe: AssetReceiveWireframeProtocol,
        iconGenerator: IconGenerating,
        accountShareFactory: NovaAccountShareFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.iconGenerator = iconGenerator
        self.accountShareFactory = accountShareFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func createChainAccountViewModel(for accountId: AccountId, chain: ChainModel) -> ChainAccountViewModel {
        let icon = try? iconGenerator.generateFromAccountId(accountId)
        let accountAddress = try? accountId.toAddress(using: chain.chainFormat)

        let viewModel = ChainAccountViewModel(
            networkName: chain.name,
            networkIconViewModel: RemoteImageViewModel(url: chain.icon),
            displayAddressViewModel: .init(
                details: accountAddress ?? "",
                imageViewModel: icon.map { DrawableIconViewModel(icon: $0) }
            )
        )
        return viewModel
    }
}

extension AssetReceivePresenter: AssetReceivePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func set(qrCodeSize: CGSize) {
        self.qrCodeSize = qrCodeSize
        interactor.generateQRCode(size: qrCodeSize)
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

extension AssetReceivePresenter: AssetReceiveInteractorOutputProtocol {
    func didReceive(
        account: MetaChainAccountResponse,
        chain: ChainModel,
        token: String
    ) {
        self.account = account
        self.chain = chain

        let chainAccountViewModel = createChainAccountViewModel(
            for: account.chainAccount.accountId,
            chain: chain
        )

        view?.didReceive(
            chainAccountViewModel: chainAccountViewModel,
            token: token
        )
    }

    func didReceive(qrCodeInfo: QRCodeInfo) {
        self.qrCodeInfo = qrCodeInfo
        view?.didReceive(qrImage: qrCodeInfo.image)
    }

    func didReceive(error: AssetReceiveInteractorError) {
        switch error {
        case .missingAccount, .encodingData:
            logger?.error(error.localizedDescription)
        case .generatingQRCode:
            guard let qrCodeSize = qrCodeSize else {
                return
            }
            let locale = localizationManager.selectedLocale
            let message = R.string.localizable.walletReceiveErrorGenerateQRCodeMessage(preferredLanguages: locale.rLanguages)
            let actionTitle = R.string.localizable.commonTryAgain(preferredLanguages: locale.rLanguages)
            let cancelAction = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)

            wireframe.presentRequestStatus(
                on: view,
                title: "",
                message: message,
                cancelAction: cancelAction,
                locale: locale
            ) { [weak self] in
                self?.interactor.generateQRCode(size: qrCodeSize)
            }
        }
    }
}
