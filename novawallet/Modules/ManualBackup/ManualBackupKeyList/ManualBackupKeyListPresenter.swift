import Foundation
import Foundation_iOS
import Operation_iOS

final class ManualBackupKeyListPresenter {
    weak var view: ManualBackupKeyListViewProtocol?
    let wireframe: ManualBackupKeyListWireframeProtocol
    let interactor: ManualBackupKeyListInteractorInputProtocol

    private let metaAccount: MetaAccountModel
    private let viewModelFactory: ManualBackupKeyListViewModelFactory
    private let walletViewModelFactory = WalletAccountViewModelFactory()
    private let logger: Logger

    private var chains: [ChainModel.Id: ChainModel] = [:]

    init(
        interactor: ManualBackupKeyListInteractorInputProtocol,
        wireframe: ManualBackupKeyListWireframeProtocol,
        viewModelFactory: ManualBackupKeyListViewModelFactory,
        metaAccount: MetaAccountModel,
        logger: Logger
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.metaAccount = metaAccount
        self.logger = logger
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

    func activateDefaultKey() {
        wireframe.showDefaultAccountBackup(
            from: view,
            with: metaAccount
        )
    }

    func activateCustomKey(with chainId: ChainModel.Id) {
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
        let viewModel = viewModelFactory.createViewModel(
            from: sortedChains.defaultChains,
            sortedChains.customChains
        )

        view?.update(with: viewModel)
    }
}

// MARK: Private

private extension ManualBackupKeyListPresenter {
    func sorted(
        _ chains: [ChainModel.Id: ChainModel],
        for metaAccount: MetaAccountModel
    ) -> SortedChains {
        let accountsChainIds = Set(metaAccount.chainAccounts.map(\.chainId))

        var defaultChains: [ChainModel] = []
        var customChains: [ChainModel] = []

        chains.forEach { chain in
            if accountsChainIds.contains(chain.key) {
                customChains.append(chain.value)
            } else if metaAccount.fetch(for: chain.value.accountRequest()) != nil {
                defaultChains.append(chain.value)
            }
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
