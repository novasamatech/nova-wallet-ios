import Foundation
import SoraFoundation
import BigInt

protocol BaseDataValidatingFactoryProtocol: AnyObject {
    var view: (ControllerBackedProtocol & Localizable)? { get }
    var basePresentable: BaseErrorPresentable { get }

    func canPayFeeAndAmount(
        balance: Decimal?,
        fee: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating

    func canPayFee(
        balance: Decimal?,
        fee: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func has(fee: Decimal?, locale: Locale, onError: (() -> Void)?) -> DataValidating

    func exsitentialDepositIsNotViolated(
        spendingAmount: BigUInt?,
        totalAmount: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating
}

extension BaseDataValidatingFactoryProtocol {
    func canPayFeeAndAmount(
        balance: Decimal?,
        fee: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentAmountTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let balance = balance,
               let fee = fee,
               let amount = spendingAmount {
                return amount + fee <= balance
            } else {
                return false
            }
        })
    }

    func canPayFee(
        balance: Decimal?,
        fee: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let viewModelFactory = BalanceViewModelFactory(targetAssetInfo: asset)

            let balanceString = viewModelFactory.amountFromValue(balance ?? 0).value(for: locale)
            let feeString = viewModelFactory.amountFromValue(fee ?? 0).value(for: locale)

            self?.basePresentable.presentFeeTooHigh(from: view, balance: balanceString, fee: feeString, locale: locale)

        }, preservesCondition: {
            if let balance = balance,
               let fee = fee {
                return fee <= balance
            } else {
                return false
            }
        })
    }

    func has(fee: Decimal?, locale: Locale, onError: (() -> Void)?) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                onError?()
            }

            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentFeeNotReceived(from: view, locale: locale)
        }, preservesCondition: { fee != nil })
    }

    func exsitentialDepositIsNotViolated(
        spendingAmount: BigUInt?,
        totalAmount: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentExistentialDepositWarning(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )

        }, preservesCondition: {
            if
                let spendingAmount = spendingAmount,
                let totalAmount = totalAmount,
                let minimumBalance = minimumBalance {
                return totalAmount - spendingAmount >= minimumBalance
            } else {
                return false
            }
        })
    }

    func canPayFeeAndAmountInPlank(
        balance: BigUInt?,
        fee: BigUInt?,
        spendingAmount: Decimal?,
        precision: Int16,
        locale: Locale
    ) -> DataValidating {
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }
        let feeDecimal = fee.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canPayFeeAndAmount(
            balance: balanceDecimal,
            fee: feeDecimal,
            spendingAmount: spendingAmount,
            locale: locale
        )
    }

    func canPayFeeInPlank(
        balance: BigUInt?,
        fee: BigUInt?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = asset.assetPrecision
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }
        let feeDecimal = fee.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canPayFee(
            balance: balanceDecimal,
            fee: feeDecimal,
            asset: asset,
            locale: locale
        )
    }

    func hasInPlank(fee: BigUInt?, locale: Locale, precision: Int16, onError: (() -> Void)?) -> DataValidating {
        let feeDecimal = fee.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return has(fee: feeDecimal, locale: locale, onError: onError)
    }
}
