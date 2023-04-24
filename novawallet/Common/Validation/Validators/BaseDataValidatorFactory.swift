import Foundation
import SoraFoundation
import BigInt

protocol BaseDataValidatingFactoryProtocol: AnyObject {
    var view: (ControllerBackedProtocol & Localizable)? { get }
    var basePresentable: BaseErrorPresentable { get }

    func canSpendAmount(
        balance: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating

    func canPayFeeSpendingAmount(
        balance: Decimal?,
        fee: Decimal?,
        spendingAmount: Decimal?,
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
    func canSpendAmount(
        balance: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentAmountTooHigh(from: view, locale: locale)

        }, preservesCondition: {
            if let balance = balance, let amount = spendingAmount {
                return amount <= balance
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

            let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: asset)

            let balanceString = tokenFormatter.value(for: locale).stringFromDecimal(balance ?? 0) ?? ""
            let feeString = tokenFormatter.value(for: locale).stringFromDecimal(fee ?? 0) ?? ""

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

    func canPayFeeSpendingAmount(
        balance: Decimal?,
        fee: Decimal?,
        spendingAmount: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let targetAmount = spendingAmount ?? 0

        if let balance = balance {
            let targetBalance = balance >= targetAmount ? balance - targetAmount : 0
            return canPayFee(
                balance: targetBalance,
                fee: fee,
                asset: asset,
                locale: locale
            )
        } else {
            return canPayFee(balance: nil, fee: fee, asset: asset, locale: locale)
        }
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

    func canSpendAmountInPlank(
        balance: BigUInt?,
        spendingAmount: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = asset.assetPrecision
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canSpendAmount(
            balance: balanceDecimal,
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

    func canPayFeeSpendingAmountInPlank(
        balance: BigUInt?,
        fee: BigUInt?,
        spendingAmount: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = asset.assetPrecision
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }
        let feeDecimal = fee.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canPayFeeSpendingAmount(
            balance: balanceDecimal,
            fee: feeDecimal,
            spendingAmount: spendingAmount,
            asset: asset,
            locale: locale
        )
    }

    func hasInPlank(fee: BigUInt?, locale: Locale, precision: Int16, onError: (() -> Void)?) -> DataValidating {
        let feeDecimal = fee.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return has(fee: feeDecimal, locale: locale, onError: onError)
    }
}
