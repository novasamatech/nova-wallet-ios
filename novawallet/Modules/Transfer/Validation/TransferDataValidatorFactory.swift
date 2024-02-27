import Foundation
import BigInt
import SoraFoundation

typealias CrossChainValidationFee = (origin: BigUInt?, crossChain: BigUInt?)

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

    // swiftlint:disable:next function_parameter_count
    func notViolatingMinBalanceBeforePayingDeliveryFee(
        for amount: Decimal?,
        networkFee: ExtrinsicFeeProtocol?,
        crosschainFee: XcmFeeModelProtocol?,
        totalBalance: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func has(crosschainFee: XcmFeeModelProtocol?, locale: Locale, onError: (() -> Void)?) -> DataValidating
}

final class TransferDataValidatorFactory: TransferDataValidatorFactoryProtocol {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let utilityAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    let presentable: TransferErrorPresentable

    init(
        presentable: TransferErrorPresentable,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        utilityAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.presentable = presentable
        self.assetDisplayInfo = assetDisplayInfo
        self.utilityAssetInfo = utilityAssetInfo
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

            let assetInfo = strongSelf.utilityAssetInfo

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

    // swiftlint:disable:next function_parameter_count
    func notViolatingMinBalanceBeforePayingDeliveryFee(
        for amount: Decimal?,
        networkFee: ExtrinsicFeeProtocol?,
        crosschainFee: XcmFeeModelProtocol?,
        totalBalance: BigUInt?,
        minBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        let assetInfo = utilityAssetInfo
        let networkFeeAmountInPlank = networkFee?.amountForCurrentAccount ?? 0
        let networkFeeDecimal = networkFeeAmountInPlank.decimal(assetInfo: assetInfo)
        let balanceDecimal = totalBalance?.decimal(assetInfo: assetInfo) ?? 0
        let minBalanceDecimal = minBalance?.decimal(assetInfo: assetInfo) ?? 0
        let amountDecimal = amount ?? 0

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: assetInfo)

            let feeAndEd = networkFeeDecimal + minBalanceDecimal
            let availableDecimal = balanceDecimal >= feeAndEd ? balanceDecimal - feeAndEd : 0

            let availableString = tokenFormatter.value(for: locale).stringFromDecimal(availableDecimal) ?? ""
            let balanceString = tokenFormatter.value(for: locale).stringFromDecimal(balanceDecimal) ?? ""
            let minBalanceString = tokenFormatter.value(for: locale).stringFromDecimal(minBalanceDecimal) ?? ""
            let networkFeeString = tokenFormatter.value(for: locale).stringFromDecimal(networkFeeDecimal) ?? ""

            self?.presentable.presentMinBalanceViolatedForDeliveryFee(
                from: view,
                params: .init(
                    totalBalance: balanceString,
                    minBalance: minBalanceString,
                    networkFee: networkFeeString,
                    availableBalance: availableString
                ),
                locale: locale
            )

        }, preservesCondition: {
            guard let crosschainFee = crosschainFee, crosschainFee.senderPart > 0 else {
                return true
            }

            return networkFeeDecimal + amountDecimal + minBalanceDecimal <= balanceDecimal
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
