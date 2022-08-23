import Foundation

final class LedgerNetworkSelectionPresenter {
    weak var view: LedgerNetworkSelectionViewProtocol?
    let wireframe: LedgerNetworkSelectionWireframeProtocol
    let interactor: LedgerNetworkSelectionInteractorInputProtocol

    private var chainAccounts: [LedgerChainAccount] = []

    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: LedgerNetworkSelectionInteractorInputProtocol,
        wireframe: LedgerNetworkSelectionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func updateView() {
        let viewModels: [ChainAccountAddViewModel] = chainAccounts.map { chainAccount in
            let displayAddressViewModel = chainAccount.address.map { displayAddressViewModelFactory.createViewModel(from: $0) }

            let chainAccountViewModel = ChainAccountViewModel(
                networkName: chainAccount.chain.name,
                networkIconViewModel: RemoteImageViewModel(url: chainAccount.chain.icon),
                displayAddressViewModel: displayAddressViewModel?.cellViewModel
            )

            return ChainAccountAddViewModel(chainAccount: chainAccountViewModel, exists: chainAccount.exists)
        }

        view?.didReceive(viewModels: viewModels)
    }
}

extension LedgerNetworkSelectionPresenter: LedgerNetworkSelectionPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectChainAccount(at index: Int) {
        let chainAccount = chainAccounts[index]

        guard !chainAccount.exists else {
            return
        }
    }
}

extension LedgerNetworkSelectionPresenter: LedgerNetworkSelectionInteractorOutputProtocol {
    func didReceive(chainAccounts: [LedgerChainAccount]) {
        self.chainAccounts = chainAccounts

        updateView()
    }
}
