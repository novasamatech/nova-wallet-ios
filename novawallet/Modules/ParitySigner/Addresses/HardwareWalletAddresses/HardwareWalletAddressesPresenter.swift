import Foundation
import Operation_iOS

class HardwareWalletAddressesPresenter {
    weak var view: HardwareWalletAddressesViewProtocol?
    let viewModelFactory: ChainAccountViewModelFactoryProtocol

    let chainList: ListDifferenceCalculator<ChainModel>
    var accountId: AccountId?

    init(viewModelFactory: ChainAccountViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    func provideViewModel() {
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

    func performSelection(
        of viewModel: ChainAccountViewModelItem,
        wireframe: AddressOptionsPresentable,
        locale: Locale
    ) {
        guard
            let chain = chainList.allItems.first(where: { $0.chainId == viewModel.chainId }),
            let address = try? accountId?.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: address, chain: chain, locale: locale)
    }
}
