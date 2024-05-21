import Foundation
import SoraFoundation
import RobinHood

final class ManualBackupKeyListPresenter {
    weak var view: ManualBackupKeyListViewProtocol?
    let wireframe: ManualBackupKeyListWireframeProtocol
    let interactor: ManualBackupKeyListInteractorInputProtocol

    private let metaAccount: MetaAccountModel
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let logger: Logger

    private var chains: [ChainModel.Id: ChainModel] = [:]

    init(
        interactor: ManualBackupKeyListInteractorInputProtocol,
        wireframe: ManualBackupKeyListWireframeProtocol,
        metaAccount: MetaAccountModel,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: Logger
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.metaAccount = metaAccount
        self.networkViewModelFactory = networkViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension ManualBackupKeyListPresenter: ManualBackupKeyListPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension ManualBackupKeyListPresenter: ManualBackupKeyListInteractorOutputProtocol {
    func didReceive(_ chainsChange: [DataProviderChange<ChainModel>]) {
        chains = chainsChange.mergeToDict(chains)

        let sortedChains = sorted(
            chains,
            for: metaAccount
        )
        let viewModel = createViewModel(from: sortedChains)
    }

    func didReceive(_: Error) {}
}

private extension ManualBackupKeyListPresenter {
    func createViewModel(from sortedChains: SortedChains) -> ManualBackupKeyListViewLayout.Model {
        let listHeaderText = R.string.localizable.chainAccountsListHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .init(
            listHeaderText: listHeaderText,
            accountsSections: [
                createDefaultChainsSection(for: sortedChains.defaultChains),
                createCustomChainsSection(for: sortedChains.customChains)
            ]
        )
    }

    func createDefaultChainsSection(for chains: [ChainModel]) -> ManualBackupKeyListViewLayout.Sections {
        let sortedDefaultChains = sorted(chains, for: metaAccount)

        let defaultChainsHeaderText = R.string.localizable.chainAccountsListDefaultHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        let defaultChainsTitleText = R.string.localizable.chainAccountsListDefaultTitle(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .defaultKeys(
            .init(
                headerText: defaultChainsHeaderText,
                accounts: [
                    .init(
                        title: defaultChainsTitleText,
                        subtitle: ""
                    )
                ]
            )
        )
    }

    func createCustomChainsSection(for chains: [ChainModel]) -> ManualBackupKeyListViewLayout.Sections {
        let customChainsViewModels = sorted(chains, for: metaAccount).compactMap {
            [weak self] chain in
            self?.networkViewModelFactory.createViewModel(from: chain)
        }

        let customChainsHeaderText = R.string.localizable.chainAccountsListCustomHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .customKeys(
            .init(
                headerText: customChainsHeaderText,
                accounts: customChainsViewModels
            )
        )
    }

    func sorted(
        _ chains: [ChainModel.Id: ChainModel],
        for metaAccount: MetaAccountModel
    ) -> SortedChains {
        let defaultChainsIds = Set(metaAccount.chainAccounts.map(\.chainId))

        var defaultChains: [ChainModel] = []
        var customChains: [ChainModel] = []

        chains.forEach { chain in
            defaultChainsIds.contains(chain.key)
                ? customChains.append(chain.value)
                : defaultChains.append(chain.value)
        }

        defaultChains.sort { ChainModelCompator.defaultComparator(chain1: $0, chain2: $1) }
        customChains.sort { ChainModelCompator.defaultComparator(chain1: $0, chain2: $1) }

        return .init(
            defaultChains: defaultChains,
            customChains: customChains
        )
    }
}

private extension ManualBackupKeyListPresenter {
    struct SortedChains {
        let defaultChains: [ChainModel]
        let customChains: [ChainModel]
    }
}
