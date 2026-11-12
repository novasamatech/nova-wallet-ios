import Foundation

extension SwapConfirmPresenter {
    func provideCommissionDisclosureViewModel() {
        let viewModel = chargesCommission
            ? viewModelFactory.commissionDisclosureViewModel(
                rate: AssetExchangeCommissionConstants.rate,
                locale: selectedLocale
            )
            : nil

        view?.didReceiveCommissionDisclosure(viewModel: viewModel)
    }
}
