import Foundation
import SoraFoundation
import RobinHood

final class ManualBackupKeyListPresenter {
    weak var view: ManualBackupKeyListViewProtocol?
    let wireframe: ManualBackupKeyListWireframeProtocol
    let interactor: ManualBackupKeyListInteractorInputProtocol

    private let metaAccount: MetaAccountModel
    private let walletViewModelFactory = WalletAccountViewModelFactory()
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

// MARK: ManualBackupKeyListPresenterProtocol

extension ManualBackupKeyListPresenter: ManualBackupKeyListPresenterProtocol {
    func setup() {
        interactor.setup()

        guard let walletViewModel = try? walletViewModelFactory.createDisplayViewModel(from: metaAccount) else {
            return
        }

        view?.updateNavbar(with: walletViewModel)
    }

    func didTapDefaultKey() {
        wireframe.showDefaultAccountBackup(
            from: view,
            with: metaAccount
        )
    }

    func didTapCustomKey(with chainId: ChainModel.Id) {
        guard let chain = chains[chainId] else { return }

        wireframe.showCustomKeyAccountBackup(from: view, with: metaAccount, chain: chain)
    }
}

// MARK: ManualBackupKeyListInteractorOutputProtocol

extension ManualBackupKeyListPresenter: ManualBackupKeyListInteractorOutputProtocol {
    func didReceive(_ chainsChange: [DataProviderChange<ChainModel>]) {
        chains = chainsChange.mergeToDict(chains)

        let sortedChains = sorted(
            chains,
            for: metaAccount
        )
        let viewModel = createViewModel(from: sortedChains)

        view?.update(with: viewModel)
    }
}

// MARK: Private

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
        let defaultChainsHeaderText = R.string.localizable.chainAccountsListDefaultHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        let defaultChainsTitleText = R.string.localizable.chainAccountsListDefaultTitle(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .defaultKeys(
            .init(
                headerText: defaultChainsHeaderText.uppercased(),
                accounts: [
                    .init(
                        title: defaultChainsTitleText,
                        subtitle: formattedString(for: chains)
                    )
                ]
            )
        )
    }

    func createCustomChainsSection(for chains: [ChainModel]) -> ManualBackupKeyListViewLayout.Sections {
        let customChainsViewModels = chains
            .compactMap { [weak self] chain -> ManualBackupKeyListViewLayout.CustomAccount? in
                guard let self else { return .none }

                return ManualBackupKeyListViewLayout.CustomAccount(
                    network: networkViewModelFactory.createViewModel(from: chain),
                    chainId: chain.chainId
                )
            }

        let customChainsHeaderText = R.string.localizable.chainAccountsListCustomHeader(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        return .customKeys(
            .init(
                headerText: customChainsHeaderText.uppercased(),
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

    func formattedString(for defaultChains: [ChainModel]) -> String {
        let chainsToMention = defaultChains.count > 1
            ? defaultChains.prefix(2)
            : defaultChains.prefix(1)
        let separator = ", "
        let restCount = defaultChains.count - chainsToMention.count

        return chainsToMention
            .map(\.name)
            .reduce(into: "") { partialResult, name in
                guard !partialResult.isEmpty else {
                    partialResult += name

                    return
                }

                var result = [partialResult, name].joined(separator: separator)

                if chainsToMention.last?.name == name, restCount > 0 {
                    let othersString = R.string.localizable.chainAccountsListDefaultSubtitle(
                        restCount,
                        preferredLanguages: localizationManager.selectedLocale.rLanguages
                    )
                    result = [result, othersString].joined(separator: separator)
                }

                partialResult = result
            }
    }
}

private extension ManualBackupKeyListPresenter {
    struct SortedChains {
        let defaultChains: [ChainModel]
        let customChains: [ChainModel]
    }
}
