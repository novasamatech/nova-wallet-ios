import Foundation
import SubstrateSdk
import SoraFoundation

final class StakingProxyManagementPresenter {
    weak var view: StakingProxyManagementViewProtocol?
    let wireframe: StakingProxyManagementWireframeProtocol
    let interactor: StakingProxyManagementInteractorInputProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol

    private lazy var novaIconGenerator = NovaIconGenerator()
    private lazy var polkadotIconGenerator = PolkadotIconGenerator()
    private var identities: [AccountId: AccountIdentity] = [:]
    private var proxyDefinition: ProxyDefinition?
    private let localizationManager: LocalizationManagerProtocol

    init(
        chainAsset: ChainAsset,
        interactor: StakingProxyManagementInteractorInputProtocol,
        wireframe: StakingProxyManagementWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func imageViewModel(from icon: DrawableIcon?, accountId: AccountId) -> IdentifiableDrawableIconViewModel? {
        guard let icon = icon else {
            return nil
        }
        let imageViewModel = DrawableIconViewModel(icon: icon)
        return .init(imageViewModel, identifier: accountId.toHexString())
    }

    private func provideViewModel() {
        guard let proxyDefinition = proxyDefinition else {
            return
        }

        let viewModels = proxyDefinition.definition.map { definition in
            let walletInfo: WalletView.ViewModel.WalletInfo

            if let name = identities[definition.proxy]?.displayName {
                let icon = try? self.novaIconGenerator.generateFromAccountId(definition.proxy)
                let imageViewModel = self.imageViewModel(from: icon, accountId: definition.proxy)
                walletInfo = .init(
                    icon: imageViewModel,
                    name: name
                )
            } else {
                let icon = try? self.polkadotIconGenerator.generateFromAccountId(definition.proxy)
                let imageViewModel = self.imageViewModel(from: icon, accountId: definition.proxy)
                let address = try? definition.proxy.toAddress(using: chainAsset.chain.chainFormat)
                walletInfo = .init(
                    icon: imageViewModel,
                    name: address ?? ""
                )
            }

            let proxyInfo = WalletView.ViewModel.ProxyInfo(
                networkIcon: RemoteImageViewModel(url: self.chainAsset.chain.icon),
                proxyType: "",
                proxyIcon: nil,
                proxyName: nil,
                isNew: false
            )

            let info = WalletView.ViewModel(wallet: walletInfo, type: .proxy(proxyInfo))

            return StakingProxyManagementViewModel(
                info: info,
                accountId: definition.proxy
            )
        }

        view?.didReceive(viewModels: viewModels)
    }

    private func showAddressOptions(address: AccountAddress) {
        guard let view = view else {
            return
        }
        let revokeAccess = AccountAdditionalOption(
            title: .init {
                R.string.localizable.stakingProxyManagementRevokeAccess(
                    preferredLanguages: $0.rLanguages
                )
            },
            icon: R.image.iconDelete(),
            indicator: .navigation
        ) { [weak self] in
            self?.wireframe.showRevokeProxyAccess(from: self?.view)
        }

        wireframe.presentExtendedAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            option: revokeAccess,
            locale: localizationManager.selectedLocale
        )
    }
}

extension StakingProxyManagementPresenter: StakingProxyManagementPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func addProxy() {
        wireframe.showAddProxy(from: view)
    }

    func showOptions(accountId: AccountId) {
        if let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) {
            showAddressOptions(address: address)
        }
    }
}

extension StakingProxyManagementPresenter: StakingProxyManagementInteractorOutputProtocol {
    func didReceive(identities: [AccountId: AccountIdentity]) {
        self.identities = identities
        provideViewModel()
    }

    func didReceive(proxyDefinition: ProxyDefinition?) {
        self.proxyDefinition = proxyDefinition
        provideViewModel()
    }

    func didReceive(error: StakingProxyManagementError) {
        switch error {
        case let .identities(error):
            logger.error("Error occured while fetching identities: \(error.localizedDescription)")
        case .proxyDefifnition:
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.interactor.setup()
            }
        }
    }
}
