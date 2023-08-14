import Foundation
import BigInt

final class EvmGasPriceValidationProvider {
    let model: EvmFeeModel
    let multiplier: BigUInt
    let divisor: BigUInt
    let presentable: EvmValidationErrorPresentable
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo

    init(
        presentable: EvmValidationErrorPresentable,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        model: EvmFeeModel,
        multiplier: BigUInt = 3,
        divisor: BigUInt = 2
    ) {
        self.presentable = presentable
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetInfo = assetInfo
        self.model = model
        self.multiplier = multiplier
        self.divisor = divisor
    }
}

extension EvmGasPriceValidationProvider: ExtrinsicValidationProviderProtocol {
    func getValidations(
        for view: ControllerBackedProtocol?,
        onRefresh: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating? {
        guard let maxPriorityPrice = model.maxPriorityGasPrice else {
            return nil
        }

        let factory = balanceViewModelFactory

        let maxPriorityFee = maxPriorityPrice * model.gasLimit
        let defaultFee = model.defaultGasPrice * model.gasLimit
        let precision = UInt16(bitPattern: assetInfo.assetPrecision)

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            let maxPriorityDecimal = maxPriorityFee.decimal(precision: precision)
            let maxPriorityString = factory.amountFromValue(maxPriorityDecimal).value(for: locale)

            let defaultDecimal = defaultFee.decimal(precision: precision)
            let defaultString = factory.amountFromValue(defaultDecimal).value(for: locale)

            self?.presentable.presentFeeToHigh(
                for: view,
                params: .init(maxPriorityFee: maxPriorityString, defaultFee: defaultString),
                onRefresh: onRefresh,
                onProceed: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: { [weak self] in
            guard let self = self else {
                return true
            }

            return self.model.defaultGasPrice * self.multiplier > maxPriorityPrice * self.divisor
        })
    }
}
