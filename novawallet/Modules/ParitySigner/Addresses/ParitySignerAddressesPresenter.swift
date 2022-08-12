import Foundation
import RobinHood

final class ParitySignerAddressesPresenter {
    weak var view: ParitySignerAddressesViewProtocol?
    let wireframe: ParitySignerAddressesWireframeProtocol
    let interactor: ParitySignerAddressesInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol

    let logger: LoggerProtocol

    private let chainList: ListDifferenceCalculator<ChainModel>
    private var accountId: AccountId?

    init(
        interactor: ParitySignerAddressesInteractorInputProtocol,
        wireframe: ParitySignerAddressesWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    private func provideViewModel() {
        if let accountId = accountId {
            let viewModels: [ChainAccountViewModelItem] = chainList.allItems.compactMap { chain in
                guard !chain.isEthereumBased else {
                    return nil
                }

                return viewModelFactory.createDefinedViewModelItem(for: accountId, chain: chain)
            }

            view?.didReceive(viewModels: viewModels)
        } else {
            view?.didReceive(viewModels: [])
        }
    }
}

extension ParitySignerAddressesPresenter: ParitySignerAddressesPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func select(viewModel: ChainAccountViewModelItem) {
        guard
            let chain = chainList.allItems.first(where: { $0.chainId == viewModel.chainId }),
            let address = try? accountId?.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: address, chain: chain, locale: view.selectedLocale)
    }

    func proceed() {
        guard let accountId = accountId else {
            return
        }

        wireframe.showConfirmation(on: view, accountId: accountId)
    }
}

extension ParitySignerAddressesPresenter: ParitySignerAddressesInteractorOutputProtocol {
    func didReceive(accountId: AccountId) {
        self.accountId = accountId

        provideViewModel()
    }

    func didReceive(chains: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: chains)

        provideViewModel()
    }

    func didReceive(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: view?.selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}
