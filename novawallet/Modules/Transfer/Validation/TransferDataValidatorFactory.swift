import Foundation
import BigInt
import Foundation_iOS

typealias CrossChainValidationFee = (origin: BigUInt?, crossChain: BigUInt?)

struct CrossChainValidationAtLeastEdForDeliveryFee {
    let amount: Decimal?
    let originNetworkFee: BigUInt?
    let originDeliveryFee: BigUInt?
    let crosschainHolding: BigUInt?
    let totalBalance: BigUInt?
    let minBalance: BigUInt?
}

struct CrossChainValidationOriginKeepAlive {
    let totalSpendingAmount: Decimal?
    let networkFee: ExtrinsicFeeProtocol?
    let balance: Balance?
    let minBalance: Balance?
    let requiresKeepAlive: Bool?
}

protocol TransferDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func willBeReaped(
        amount: Decimal?,
        fee: ExtrinsicFeeProtocol?,
        totalAmount: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func receiverHasAccountProvider(
        utilityTotalAmount: BigUInt?,
        utilityMinBalance: BigUInt?,
        assetExistence: AssetBalanceExistence?,
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

    func receiverNotBlocked(_ isBlocked: Bool?, locale: Locale) -> DataValidating

    func canPayOriginDeliveryFee(
        for amount: Decimal?,
        networkFee: ExtrinsicFeeProtocol?,
        crosschainFee: XcmFeeModelProtocol?,
        transferable: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func canPayCrossChainFee(
        for amount: Decimal?,
        fee: CrossChainValidationFee?,
        transferable: BigUInt?,
        destinationAsset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func notViolatingMinBalanceWhenDeliveryFeeEnabled(
        for params: CrossChainValidationAtLeastEdForDeliveryFee,
        locale: Locale
    ) -> DataValidating

    func notViolatingKeepAlive(
        for params: CrossChainValidationOriginKeepAlive,
        locale: Locale
    ) -> DataValidating

    func has(crosschainFee: XcmFeeModelProtocol?, locale: Locale, onError: (() -> Void)?) -> DataValidating
}

final class TransferDataValidatorFactory: TransferDataValidatorFactoryProtocol {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let utilityAssetInfo: AssetBalanceDisplayInfo
    let destUtilityAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    let presentable: TransferErrorPresentable

    init(
        presentable: TransferErrorPresentable,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        utilityAssetInfo: AssetBalanceDisplayInfo,
        destUtilityAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.presentable = presentable
        self.assetDisplayInfo = assetDisplayInfo
        self.utilityAssetInfo = utilityAssetInfo
        self.destUtilityAssetInfo = destUtilityAssetInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }

    func has(crosschainFee: XcmFeeModelProtocol?, locale: Locale, onError: (() -> Void)?) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            defer {
                onError?()
            }

            guard let view = self?.view else {
                return
            }

            self?.basePresentable.presentFeeNotReceived(from: view, locale: locale)
        }, preservesCondition: { crosschainFee != nil })
    }

    func willBeReaped(
        amount: Decimal?,
        fee: ExtrinsicFeeProtocol?,
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
                let minBalance = minBalance {
                let feeAmount = fee?.amountForCurrentAccount ?? 0
                return totalAmount >= minBalance + sendingAmount + feeAmount
            } else {
                return false
            }
        })
    }

    func receiverHasAccountProvider(
        utilityTotalAmount: BigUInt?,
        utilityMinBalance: BigUInt?,
        assetExistence: AssetBalanceExistence?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let strongSelf = self, let view = strongSelf.view else {
                return
            }

            let assetInfo = strongSelf.destUtilityAssetInfo

            self?.presentable.presentNoReceiverAccount(
                for: assetInfo.symbol,
                from: view,
                locale: locale
            )

        }, preservesCondition: {
            if let assetExistence = assetExistence, assetExistence.isSelfSufficient {
                return true
            }

            if let totalAmount = utilityTotalAmount, let minBalance = utilityMinBalance {
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

    func receiverNotBlocked(_ isBlocked: Bool?, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            self?.presentable.presentReceivedBlocked(from: self?.view, locale: locale)

        }, preservesCondition: {
            !(isBlocked ?? false)
        })
    }

    func canPayOriginDeliveryFee(
        for amount: Decimal?,
        networkFee: ExtrinsicFeeProtocol?,
        crosschainFee: XcmFeeModelProtocol?,
        transferable: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        let assetInfo = utilityAssetInfo
        let feeAmountInPlank = (networkFee?.amountForCurrentAccount ?? 0) + (crosschainFee?.senderPart ?? 0)
        let feeDecimal = feeAmountInPlank.decimal(assetInfo: assetInfo)
        let balanceDecimal = transferable?.decimal(assetInfo: assetInfo) ?? 0
        let amountDecimal = amount ?? 0

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: assetInfo)

            let balanceAfterOperation = balanceDecimal >= amountDecimal ? balanceDecimal - amountDecimal : 0
            let balanceString = tokenFormatter.value(for: locale).stringFromDecimal(balanceAfterOperation) ?? ""
            let feeString = tokenFormatter.value(for: locale).stringFromDecimal(feeDecimal) ?? ""

            self?.basePresentable.presentFeeTooHigh(from: view, balance: balanceString, fee: feeString, locale: locale)

        }, preservesCondition: {
            feeDecimal + amountDecimal <= balanceDecimal
        })
    }

    func notViolatingMinBalanceWhenDeliveryFeeEnabled(
        for params: CrossChainValidationAtLeastEdForDeliveryFee,
        locale: Locale
    ) -> DataValidating {
        let assetInfo = utilityAssetInfo
        let networkFeeAmountInPlank = params.originNetworkFee ?? 0
        let networkFeeDecimal = networkFeeAmountInPlank.decimal(assetInfo: assetInfo)
        let deliveryFeeInPlank = params.originDeliveryFee ?? 0
        let deliveryFeeDecimal = deliveryFeeInPlank.decimal(assetInfo: assetInfo)
        let balanceDecimal = params.totalBalance?.decimal(assetInfo: assetInfo) ?? 0
        let minBalanceDecimal = params.minBalance?.decimal(assetInfo: assetInfo) ?? 0
        let crosschainHoldingDecimal = params.crosschainHolding?.decimal(assetInfo: assetInfo) ?? 0
        let sendingDecimal = (params.amount ?? 0) + crosschainHoldingDecimal

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: assetInfo)

            let feeAndEd = networkFeeDecimal + deliveryFeeDecimal + minBalanceDecimal + crosschainHoldingDecimal
            let availableDecimal = balanceDecimal >= feeAndEd ? balanceDecimal - feeAndEd : 0

            let availableString = tokenFormatter.value(for: locale).stringFromDecimal(availableDecimal) ?? ""

            self?.presentable.presentMinBalanceViolatedForDeliveryFee(
                from: view,
                availableBalance: availableString,
                locale: locale
            )

        }, preservesCondition: {
            guard let originDeliveryFee = params.originDeliveryFee, originDeliveryFee > 0 else {
                return true
            }

            return networkFeeDecimal + deliveryFeeDecimal + sendingDecimal + minBalanceDecimal <= balanceDecimal
        })
    }

    func notViolatingKeepAlive(
        for params: CrossChainValidationOriginKeepAlive,
        locale: Locale
    ) -> DataValidating {
        let totalSpendingInPlank = params.totalSpendingAmount?.toSubstrateAmount(
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let assetInfo = self?.assetDisplayInfo else {
                return
            }

            let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: assetInfo)

            let minBalanceDecimal = params.minBalance?.decimal(assetInfo: assetInfo) ?? 0

            let minBalanceString = tokenFormatter.value(for: locale).stringFromDecimal(minBalanceDecimal) ?? ""

            self?.presentable.presentKeepAliveViolatedForCrosschain(
                from: view,
                minBalance: minBalanceString,
                locale: locale
            )

        }, preservesCondition: {
            guard
                let balance = params.balance,
                let minBalance = params.minBalance,
                let requiresKeepAlive = params.requiresKeepAlive else {
                return true
            }

            if requiresKeepAlive {
                let feeAmount = params.networkFee?.amountForCurrentAccount ?? 0
                return totalSpendingInPlank + feeAmount + minBalance <= balance
            } else {
                return true
            }
        })
    }

    func canPayCrossChainFee(
        for amount: Decimal?,
        fee: CrossChainValidationFee?,
        transferable: BigUInt?,
        destinationAsset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = assetDisplayInfo.assetPrecision
        let sendingAmount = amount.flatMap {
            $0.toSubstrateAmount(precision: precision)
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view,
                  let originAsset = self?.assetDisplayInfo,
                  let priceAssetInfoFactory = self?.priceAssetInfoFactory else {
                return
            }

            let destBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: destinationAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
            let originBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: originAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            )

            let crossChainFeeDecimal = Decimal.fromSubstrateAmount(
                fee?.crossChain ?? 0,
                precision: destinationAsset.assetPrecision
            ) ?? 0

            let crossChainFeeString = destBalanceViewModelFactory.amountFromValue(crossChainFeeDecimal)
                .value(for: locale)

            let sendingAmountDecimal = amount ?? 0
            let transferableDecimal = Decimal.fromSubstrateAmount(
                transferable ?? 0,
                precision: originAsset.assetPrecision
            ) ?? 0

            let originFeeDecimal = Decimal.fromSubstrateAmount(
                fee?.origin ?? 0,
                precision: originAsset.assetPrecision
            ) ?? 0

            let remainingString = originBalanceViewModelFactory.amountFromValue(
                max(transferableDecimal - sendingAmountDecimal - originFeeDecimal, 0)
            ).value(for: locale)

            self?.presentable.presentCantPayCrossChainFee(
                from: view,
                feeString: crossChainFeeString,
                balance: remainingString,
                locale: locale
            )

        }, preservesCondition: {
            if let sendingAmount = sendingAmount, let transferable = transferable {
                let originFeeAmount = fee?.origin ?? 0
                let crosschainFeeAmount = fee?.crossChain ?? 0
                return sendingAmount + originFeeAmount + crosschainFeeAmount <= transferable
            } else {
                return false
            }
        })
    }
}
