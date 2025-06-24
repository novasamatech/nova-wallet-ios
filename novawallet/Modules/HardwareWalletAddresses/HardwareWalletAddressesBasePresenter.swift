import Foundation
import Operation_iOS

class HardwareWalletAddressesBasePresenter {
    weak var view: HardwareWalletAddressesViewProtocol?
    let viewModelFactory: ChainAccountViewModelFactoryProtocol

    let chainList: ListDifferenceCalculator<ChainModel>

    init(viewModelFactory: ChainAccountViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    func performSelection(
        of viewModel: ChainAccountViewModelItem,
        wireframe: AddressOptionsPresentable,
        locale: Locale
    ) {
        guard
            let chain = chainList.allItems.first(where: { $0.chainId == viewModel.chainId }),
            let address = viewModel.address,
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: address, chain: chain, locale: locale)
    }
}
