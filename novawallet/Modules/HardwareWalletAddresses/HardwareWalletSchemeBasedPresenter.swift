import Foundation

class HardwareWalletSchemeBasedPresenter: HardwareWalletAddressesBasePresenter {
    var addresses: [HardwareWalletAddressModel] = []

    func provideViewModel() {
        let sections = addresses.compactMap { address in
            createSectionViewModel(for: address)
        }

        let viewModel = HardwareWalletAddressesViewModel(sections: sections)
        view?.didReceive(viewModel: viewModel)
    }
}

private extension HardwareWalletSchemeBasedPresenter {
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
            addressScheme: model.scheme,
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
