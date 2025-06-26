import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

final class ParitySignerAddressesPresenter: HardwareWalletAddressesBasePresenter {
    let wireframe: ParitySignerAddressesWireframeProtocol
    let interactor: ParitySignerAddressesInteractorInputProtocol
    let type: ParitySignerType
    let walletUpdate: PolkadotVaultWalletUpdate

    let logger: LoggerProtocol

    init(
        walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType,
        interactor: ParitySignerAddressesInteractorInputProtocol,
        wireframe: ParitySignerAddressesWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.walletUpdate = walletUpdate
        self.type = type
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init(viewModelFactory: viewModelFactory)

        self.localizationManager = localizationManager
    }
}

private extension ParitySignerAddressesPresenter {
    private func createSection(
        with title: LocalizableResource<String>,
        from chainAccounts: [ConsensusBasedAccountModel.ChainAccount]
    ) -> HardwareWalletAddressesViewModel.Section {
        let items = chainAccounts.map {
            viewModelFactory.createDefinedViewModelItem(for: $0.accountId, chain: $0.chain)
        }

        return HardwareWalletAddressesViewModel.Section(title: title, items: items)
    }

    func provideViewModel() {
        let accountByChain: [ChainModel.Id: AccountId] = walletUpdate.addressItems.reduce(
            into: [:]
        ) { accum, account in
            accum[account.genesisHash.toHex()] = account.accountId
        }

        let sortedChains = chainList.allItems.filter { $0.hasSubstrateRuntime }

        let model = ConsensusBasedAccountModelFactory.createFromAccounts(accountByChain, sortedChains: sortedChains)

        var sections: [HardwareWalletAddressesViewModel.Section] = []

        if !model.customDerivationAccounts.isEmpty {
            let section = createSection(
                with: LocalizableResource { _ in
                    "Custom derivations".uppercased()
                },
                from: model.customDerivationAccounts
            )

            sections.append(section)
        }

        if !model.solochainAccounts.isEmpty {
            let section = createSection(
                with: LocalizableResource { _ in
                    "Solochain accounts".uppercased()
                },
                from: model.solochainAccounts
            )

            sections.append(section)
        }

        if !model.evmAccounts.isEmpty {
            let section = createSection(
                with: LocalizableResource { _ in
                    "Evm accounts".uppercased()
                },
                from: model.evmAccounts
            )

            sections.append(section)
        }

        let consensusSections = model.consensusAccounts.map { account in
            let title = LocalizableResource { _ in
                (account.relay.name + " accounts").uppercased()
            }

            let items = account.chains.map { chain in
                viewModelFactory.createDefinedViewModelItem(for: account.accountId, chain: chain)
            }

            return HardwareWalletAddressesViewModel.Section(title: title, items: items)
        }

        sections.append(contentsOf: consensusSections)

        view?.didReceive(viewModel: .init(sections: sections))
    }

    func provideDescriptionViewModel() {
        let languages = selectedLocale.rLanguages
        let viewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.paritySignerAddressesTitle(preferredLanguages: languages),
            subtitle: R.string.localizable.paritySignerAddressesSubtitle(
                type.getName(for: selectedLocale),
                preferredLanguages: languages
            )
        )

        view?.didReceive(descriptionViewModel: viewModel)
    }
}

extension ParitySignerAddressesPresenter: HardwareWalletAddressesPresenterProtocol {
    func setup() {
        provideDescriptionViewModel()
        interactor.setup()
    }

    func select(viewModel: ChainAccountViewModelItem) {
        performSelection(of: viewModel, wireframe: wireframe, locale: selectedLocale)
    }

    func proceed() {
        interactor.confirm()
    }
}

extension ParitySignerAddressesPresenter: ParitySignerAddressesInteractorOutputProtocol {
    func didReceive(chains: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: chains)

        provideViewModel()
    }

    func didReceiveConfirm(result: Result<Void, Error>) {
        switch result {
        case .success:
            wireframe.showConfirmation(on: view, walletUpdate: walletUpdate, type: type)
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

extension ParitySignerAddressesPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideDescriptionViewModel()
        }
    }
}
