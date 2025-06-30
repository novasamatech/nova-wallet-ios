import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

final class MultisigOperationsPresenter {
    weak var view: MultisigOperationsViewProtocol?
    let wireframe: MultisigOperationsWireframeProtocol
    let interactor: MultisigOperationsInteractorInputProtocol
    let viewModelFactory: MultisigOperationsViewModelFactoryProtocol

    private let wallet: MetaAccountModel

    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var operations: [Multisig.PendingOperation] = []

    init(
        interactor: MultisigOperationsInteractorInputProtocol,
        wireframe: MultisigOperationsWireframeProtocol,
        viewModelFactory: MultisigOperationsViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension MultisigOperationsPresenter {
    func provideViewModel() {
        guard !operations.isEmpty, !chains.isEmpty else {
            return
        }

        let viewModel = viewModelFactory.createListViewModel(
            from: operations,
            chains: chains,
            wallet: wallet,
            for: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - MultisigOperationsPresenterProtocol

extension MultisigOperationsPresenter: MultisigOperationsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectOperation(with id: String) {
        guard let operation = operations.first(where: { $0.identifier == id }) else { return }

        wireframe.showOperationDetails(
            from: view,
            operation: operation
        )
    }
}

// MARK: - MultisigOperationsInteractorOutputProtocol

extension MultisigOperationsPresenter: MultisigOperationsInteractorOutputProtocol {
    func didReceiveOperations(changes: [DataProviderChange<Multisig.PendingOperation>]) {
        operations = operations.applying(changes: changes)
        provideViewModel()
    }

    func didReceiveChains(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
        provideViewModel()
    }

    func didReceive(error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: - Localizable

extension MultisigOperationsPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else { return }

        provideViewModel()
    }
}
