import Foundation
import Foundation_iOS

final class LedgerNetworkSelectionPresenter {
    weak var view: LedgerNetworkSelectionViewProtocol?
    let wireframe: LedgerNetworkSelectionWireframeProtocol
    let interactor: LedgerNetworkSelectionInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private var chainAccounts: [LedgerChainAccount] = []

    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: LedgerNetworkSelectionInteractorInputProtocol,
        wireframe: LedgerNetworkSelectionWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let viewModels: [ChainAccountAddViewModel] = chainAccounts.map { chainAccount in
            let displayAddressViewModel = chainAccount.address.map { address in
                displayAddressViewModelFactory.createViewModel(from: address)
            }

            let chainAccountViewModel = ChainAccountViewModel(
                networkName: chainAccount.chain.name,
                networkIconViewModel: ImageViewModelFactory.createChainIconOrDefault(from: chainAccount.chain.icon),
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

        wireframe.showLedgerDiscovery(from: view, chain: chainAccount.chain)
    }

    func cancel() {
        guard let view = view else {
            return
        }

        wireframe.presentCancelOperation(
            from: view,
            locale: localizationManager.selectedLocale
        ) { [weak self, weak view] in
            self?.wireframe.close(view: view)
        }
    }

    func proceed() {
        wireframe.showWalletCreate(from: view)
    }
}

extension LedgerNetworkSelectionPresenter: LedgerNetworkSelectionInteractorOutputProtocol {
    func didReceive(chainAccounts: [LedgerChainAccount]) {
        self.chainAccounts = chainAccounts

        updateView()
    }
}
