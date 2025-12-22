import Foundation
import Foundation_iOS
import SubstrateSdk
import UIKit

final class AssetReceivePresenter {
    weak var view: AssetReceiveViewProtocol?
    let wireframe: AssetReceiveWireframeProtocol
    let interactor: AssetReceiveInteractorInputProtocol
    let iconGenerator: IconGenerating
    let accountShareFactory: NovaAccountShareFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    let logger: LoggerProtocol?

    private var qrCodeInfo: QRCodeInfo?
    private var account: MetaChainAccountResponse?
    private var chain: ChainModel?
    private var qrCodeSize: CGSize?
    private var token: String?

    init(
        interactor: AssetReceiveInteractorInputProtocol,
        wireframe: AssetReceiveWireframeProtocol,
        iconGenerator: IconGenerating,
        accountShareFactory: NovaAccountShareFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.iconGenerator = iconGenerator
        self.accountShareFactory = accountShareFactory
        self.logger = logger
        self.networkViewModelFactory = networkViewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension AssetReceivePresenter {
    func createChainAccountViewModel(for accountId: AccountId, chain: ChainModel) -> ChainAccountViewModel {
        let icon = try? iconGenerator.generateFromAccountId(accountId)
        let accountAddress = try? accountId.toAddress(using: chain.chainFormat)

        let viewModel = ChainAccountViewModel(
            networkName: chain.name,
            networkIconViewModel: ImageViewModelFactory.createChainIconOrDefault(from: chain.icon),
            displayAddressViewModel: .init(
                details: accountAddress ?? "",
                imageViewModel: icon.map { DrawableIconViewModel(icon: $0) }
            )
        )
        return viewModel
    }

    func provideNetwork() {
        guard let chain else { return }

        let networkViewModel = networkViewModelFactory.createViewModel(from: chain)

        view?.didReceive(networkViewModel: networkViewModel)
    }

    func provideAddress() {
        guard
            let account,
            let chain,
            let token
        else {
            return
        }

        let addressViewModel = AccountAddressViewModel(
            walletName: account.chainAccount.name,
            address: account.chainAccount.toAddress(),
            hasLegacyAddress: chain.hasUnifiedAddressPrefix
        )

        view?.didReceive(
            addressViewModel: addressViewModel,
            networkName: chain.name,
            token: token
        )
    }
}

// MARK: AssetReceivePresenterProtocol

extension AssetReceivePresenter: AssetReceivePresenterProtocol {
    func viewAddressFormats() {
        guard
            let chain,
            let address = account?.chainAccount.toAddress(),
            let legacyAddress = try? address.toLegacySubstrateAddress(for: chain.chainFormat)
        else {
            return
        }

        wireframe.presentUnifiedAddressPopup(
            from: view,
            newAddress: address,
            legacyAddress: legacyAddress
        )
    }

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
            qrImage: qrCodeInfo.result.image
        )

        wireframe.share(
            items: sharingItems,
            from: view,
            with: nil
        )
    }

    func copyAddress() {
        guard
            let address = account?.chainAccount.toAddress(),
            let chain
        else {
            return
        }

        wireframe.copyAddressCheckingFormat(
            from: view,
            address: address,
            chain: chain,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: AssetReceiveInteractorOutputProtocol

extension AssetReceivePresenter: AssetReceiveInteractorOutputProtocol {
    func didReceive(
        account: MetaChainAccountResponse,
        chain: ChainModel,
        token: String
    ) {
        self.account = account
        self.chain = chain
        self.token = token

        provideNetwork()
        provideAddress()
    }

    func didReceive(qrCodeInfo: QRCodeInfo) {
        self.qrCodeInfo = qrCodeInfo
        view?.didReceive(qrResult: qrCodeInfo.result)
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
            let message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.walletReceiveErrorGenerateQRCodeMessage()
            let cancelAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()

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
