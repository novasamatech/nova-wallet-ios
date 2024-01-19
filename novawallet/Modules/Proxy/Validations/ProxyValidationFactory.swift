import Foundation
import SoraFoundation
import BigInt

protocol ProxyDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func canPayFee(
        balance: Decimal?,
        fee: ExtrinsicFeeProtocol?,
        proxyName: String,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating
}

extension ProxyDataValidatorFactoryProtocol {
    func canPayFeeInPlank(
        balance: BigUInt?,
        fee: ExtrinsicFeeProtocol?,
        proxyName _: String,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = asset.assetPrecision
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canPayFee(
            balance: balanceDecimal,
            fee: fee,
            asset: asset,
            locale: locale
        )
    }
}

final class ProxyDataValidatorFactory: ProxyDataValidatorFactoryProtocol {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: ProxyErrorPresentable

    init(presentable: ProxyErrorPresentable) {
        self.presentable = presentable
    }

    func canPayFee(
        balance: Decimal?,
        fee: ExtrinsicFeeProtocol?,
        proxyName: String,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: asset)

            let balanceString = tokenFormatter.value(for: locale).stringFromDecimal(balance ?? 0) ?? ""
            let feeDecimal = fee?.amountForCurrentAccount?.decimal(assetInfo: asset)
            let feeString = tokenFormatter.value(for: locale).stringFromDecimal(feeDecimal ?? 0) ?? ""

            self?.presentable.presentFeeTooHigh(
                from: view,
                balance: balanceString,
                fee: feeString,
                accountName: proxyName,
                locale: locale
            )

        }, preservesCondition: {
            guard let balance = balance, let fee = fee else {
                return false
            }

            guard let feeAmountInPlank = fee.amountForCurrentAccount else {
                return true
            }

            let feeAmount = feeAmountInPlank.decimal(assetInfo: asset)

            return feeAmount <= balance
        })
    }
}
