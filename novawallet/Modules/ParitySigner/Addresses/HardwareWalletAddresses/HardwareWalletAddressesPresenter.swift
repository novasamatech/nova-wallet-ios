import Foundation
import Operation_iOS

class HardwareWalletAddressesPresenter {
    weak var view: HardwareWalletAddressesViewProtocol?
    let viewModelFactory: ChainAccountViewModelFactoryProtocol

    let chainList: ListDifferenceCalculator<ChainModel>
    var addresses: [HardwareWalletAddressModel] = []

    init(viewModelFactory: ChainAccountViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory

        chainList = ListDifferenceCalculator(initialItems: []) { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }
    }

    func provideViewModel() {
        let sections = addresses.compactMap { address in
            createSectionViewModel(for: address)
        }

        let viewModel = HardwareWalletAddressesViewModel(sections: sections)
        view?.didReceive(viewModel: viewModel)
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

private extension HardwareWalletAddressesPresenter {
    func createSectionViewModel(
        for model: HardwareWalletAddressModel
    ) -> HardwareWalletAddressesViewModel.Section? {
        guard let accountId = model.accountId else {
            return nil
        }

        let chains = getChains(for: model.scheme)

        let items = chains.map { chain in
            viewModelFactory.createDefinedViewModelItem(for: accountId, chain: chain)
        }

        return HardwareWalletAddressesViewModel.Section(
            scheme: model.scheme,
            items: items
        )
    }

    func getChains(for scheme: HardwareWalletAddressScheme) -> [ChainModel] {
        chainList.allItems.filter { chain in
            switch scheme {
            case .substrate:
                return !chain.isEthereumBased
            case .evm:
                return chain.isEthereumBased
            }
        }
    }
}
