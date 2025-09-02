import Foundation
import Foundation_iOS
import BigInt

protocol BaseDataValidatingFactoryProtocol: AnyObject {
    var view: ControllerBackedProtocol? { get }
    var basePresentable: BaseErrorPresentable { get }

    func canSpendAmount(
        balance: Decimal?,
        spendingAmount: Decimal?,
        locale: Locale
    ) -> DataValidating

    func canPayFeeSpendingAmount(
        balance: Decimal?,
        fee: ExtrinsicFeeProtocol?,
        spendingAmount: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func has(fee: ExtrinsicFeeProtocol?, locale: Locale, onError: (() -> Void)?) -> DataValidating

    func exsitentialDepositIsNotViolated(
        spendingAmount: BigUInt?,
        totalAmount: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func accountIsNotSystem(for accountId: AccountId?, locale: Locale) -> DataValidating

    func notViolatingMinBalancePaying(
        fee: ExtrinsicFeeProtocol?,
        total: BigUInt?,
        minBalance: BigUInt?,
        asset: AssetBalanceDisplayInfo,
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
        fee: ExtrinsicFeeProtocol?,
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

            self?.basePresentable.presentFeeTooHigh(from: view, balance: balanceString, fee: feeString, locale: locale)

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

    func canPayFeeSpendingAmount(
        balance: Decimal?,
        fee: ExtrinsicFeeProtocol?,
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

    func has(fee: ExtrinsicFeeProtocol?, locale: Locale, onError: (() -> Void)?) -> DataValidating {
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
        fee: ExtrinsicFeeProtocol?,
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

    func canPayFeeSpendingAmountInPlank(
        balance: BigUInt?,
        fee: ExtrinsicFeeProtocol?,
        spendingAmount: Decimal?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = asset.assetPrecision
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canPayFeeSpendingAmount(
            balance: balanceDecimal,
            fee: fee,
            spendingAmount: spendingAmount,
            asset: asset,
            locale: locale
        )
    }

    func accountIsNotSystem(for accountId: AccountId?, locale: Locale) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentIsSystemAccount(
                from: view,
                onContinue: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let accountId = accountId else {
                return true
            }

            let validation = CompoundSystemAccountValidation.substrateAccounts()

            return !validation.isSystem(accountId: accountId)
        })
    }

    func notViolatingMinBalancePaying(
        fee: ExtrinsicFeeProtocol?,
        total: BigUInt?,
        minBalance: BigUInt?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let tokenFormatter = AssetBalanceFormatterFactory()
                .createTokenFormatter(for: asset)
                .value(for: locale)

            let feeDecimal = fee?.amountForCurrentAccount?.decimal(assetInfo: asset) ?? 0
            let minBalanceDecimal = minBalance?.decimal(assetInfo: asset) ?? 0
            let feeAndMinBalanceDecimal = feeDecimal + minBalanceDecimal
            let totalDecimal = total?.decimal(assetInfo: asset) ?? 0
            let needToAddDecimal = max(feeAndMinBalanceDecimal - totalDecimal, 0)

            let totalString = tokenFormatter.stringFromDecimal(totalDecimal)
            let feeAndMinBalanceString = tokenFormatter.stringFromDecimal(feeAndMinBalanceDecimal)
            let needToAddString = tokenFormatter.stringFromDecimal(needToAddDecimal)

            self?.basePresentable.presentMinBalanceViolated(
                from: view,
                minBalanceForOperation: feeAndMinBalanceString ?? "",
                currentBalance: totalString ?? "",
                needToAddBalance: needToAddString ?? "",
                locale: locale
            )

        }, preservesCondition: {
            guard let feeAmount = fee?.amountForCurrentAccount else {
                return true
            }

            if let total = total, let minBalance = minBalance {
                return feeAmount + minBalance <= total
            } else {
                return false
            }
        })
    }
}
