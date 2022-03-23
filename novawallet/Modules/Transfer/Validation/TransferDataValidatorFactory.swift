import Foundation
import BigInt
import SoraFoundation

protocol TransferDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func canSend(
        amount: Decimal?,
        fee: BigUInt?,
        transferable: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func has(fee: BigUInt?, locale: Locale, onError: (() -> Void)?) -> DataValidating

    func canPay(fee: BigUInt?, total: BigUInt?, minBalance: BigUInt?, locale: Locale) -> DataValidating

    func willBeReaped(
        amount: Decimal?,
        fee: BigUInt?,
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func receiverHasUtilityAccount(
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func receiverWillHaveAssetAccount(
        sendingAmount: Decimal?,
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func receiverDiffers(
        recepient: AccountAddress?,
        sender: AccountAddress,
        locale: Locale
    ) -> DataValidating

    func receiverMatchesChain(
        recepient: AccountAddress?,
        chainFormat: ChainFormat,
        chainName: String,
        locale: Locale
    ) -> DataValidating
}

final class TransferDataValidatorFactory: TransferDataValidatorFactoryProtocol {
    weak var view: (Localizable & ControllerBackedProtocol)?

    var basePresentable: BaseErrorPresentable { presentable }
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let utilityAssetInfo: AssetBalanceDisplayInfo?

    let presentable: TransferErrorPresentable

    init(
        presentable: TransferErrorPresentable,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        utilityAssetInfo: AssetBalanceDisplayInfo?
    ) {
        self.presentable = presentable
        self.assetDisplayInfo = assetDisplayInfo
        self.utilityAssetInfo = utilityAssetInfo
    }

    func canSend(
        amount: Decimal?,
        fee: BigUInt?,
        transferable: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let sendingAmount = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentAmountTooHigh(from: view, locale: locale)
        }, preservesCondition: {
            if
                let sendingAmount = sendingAmount,
                let fee = fee,
                let transferable = transferable {
                return sendingAmount + fee <= transferable
            } else {
                return false
            }
        })
    }

    func has(fee: BigUInt?, locale: Locale, onError: (() -> Void)?) -> DataValidating {
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

    func canPay(fee: BigUInt?, total: BigUInt?, minBalance: BigUInt?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCantPayFee(from: view, locale: locale)

        }, preservesCondition: {
            if
                let total = total,
                let fee = fee,
                let minBalance = minBalance {
                return fee + minBalance <= total
            } else {
                return false
            }
        })
    }

    func willBeReaped(
        amount: Decimal?,
        fee: BigUInt?,
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let sendingAmount = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return WarningConditionViolation(onWarning: { [weak self] delegate in
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
                let sendingAmount = sendingAmount,
                let totalAmount = totalAmount,
                let minBalance = minBalance,
                let fee = fee {
                return totalAmount >= minBalance + sendingAmount + fee
            } else {
                return false
            }
        })
    }

    func receiverHasUtilityAccount(
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let strongSelf = self, let view = strongSelf.view else {
                return
            }

            let assetInfo = strongSelf.utilityAssetInfo ?? strongSelf.assetDisplayInfo

            self?.presentable.presentNoReceiverAccount(
                for: assetInfo.symbol,
                from: view,
                locale: locale
            )

        }, preservesCondition: {
            if
                let totalAmount = totalAmount,
                let minBalance = minBalance {
                return minBalance <= totalAmount
            } else {
                return false
            }
        })
    }

    func receiverWillHaveAssetAccount(
        sendingAmount: Decimal?,
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        let sendingAmountValue: BigUInt

        if let sendingAmount = sendingAmount {
            let precision = assetDisplayInfo.assetPrecision
            sendingAmountValue = sendingAmount.toSubstrateAmount(precision: precision) ?? 0
        } else {
            sendingAmountValue = 0
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentReceiverBalanceTooLow(from: view, locale: locale)

        }, preservesCondition: {
            if
                let totalAmount = totalAmount,
                let minBalance = minBalance {
                return totalAmount + sendingAmountValue >= minBalance
            } else {
                return false
            }
        })
    }

    func receiverDiffers(
        recepient: AccountAddress?,
        sender: AccountAddress,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentSameReceiver(from: view, locale: locale)
        }, preservesCondition: {
            recepient != sender
        })
    }

    func receiverMatchesChain(
        recepient: AccountAddress?,
        chainFormat: ChainFormat,
        chainName: String,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentWrongChain(for: chainName, from: view, locale: locale)

        }, preservesCondition: {
            let accountId = try? recepient?.toAccountId(using: chainFormat)
            return accountId != nil
        })
    }
}
