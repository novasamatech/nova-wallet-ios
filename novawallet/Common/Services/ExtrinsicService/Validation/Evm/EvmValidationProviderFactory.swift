import Foundation

protocol EvmValidationProviderFactoryProtocol {
    func createGasPriceValidation(for model: EvmFeeModel) -> ExtrinsicValidationProviderProtocol
}

final class EvmValidationProviderFactory {
    let presentable: EvmValidationErrorPresentable
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo

    init(
        presentable: EvmValidationErrorPresentable,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo
    ) {
        self.presentable = presentable
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetInfo = assetInfo
    }
}

extension EvmValidationProviderFactory: EvmValidationProviderFactoryProtocol {
    func createGasPriceValidation(for model: EvmFeeModel) -> ExtrinsicValidationProviderProtocol {
        EvmGasPriceValidationProvider(
            presentable: presentable,
            balanceViewModelFactory: balanceViewModelFactory,
            assetInfo: assetInfo,
            model: model
        )
    }
}
