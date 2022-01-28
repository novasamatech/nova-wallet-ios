import Foundation
import CommonWallet

final class TransferValidator: TransferValidating {
    let utilityAsset: AssetModel

    init(utilityAsset: AssetModel) {
        self.utilityAsset = utilityAsset
    }

    func validate(
        info: TransferInfo,
        balances: [BalanceData],
        metadata: TransferMetaData
    ) throws -> TransferInfo {
        let sendingAmount = info.amount.decimalValue
        guard sendingAmount > 0 else {
            throw TransferValidatingError.zeroAmount
        }

        guard let balanceData = balances.first(where: { $0.identifier == info.asset }) else {
            throw TransferValidatingError.missingBalance(assetId: info.asset)
        }

        let balanceContext = BalanceContext(context: balanceData.context ?? [:])

        let availableBalance = balanceContext.available
        let totalBalance = balanceContext.total

        guard senderHasAssetsToSend(
            info: info,
            availableBalance: availableBalance,
            metadata: metadata
        ) else {
            throw TransferValidatingError.unsufficientFunds(
                assetId: info.asset,
                available: availableBalance
            )
        }

        guard senderHasAssetsToPayFee(
            info: info,
            totalBalance: totalBalance,
            metadata: metadata
        ) else {
            throw NovaTransferValidatingError.cantPayFee
        }

        guard receiverHasMainAccount(in: metadata) else {
            throw NovaTransferValidatingError.noReceiverAccount(assetSymbol: utilityAsset.symbol)
        }

        guard receiverCanReceive(amount: sendingAmount, metadata: metadata) else {
            throw NovaTransferValidatingError.receiverBalanceTooLow
        }

        let senderWillBeDead = senderWillBeDead(info: info, totalBalance: totalBalance, metadata: metadata)
        let transferInfoContext = TransferInfoContext(
            balanceContext: balanceContext,
            accountWillBeDead: senderWillBeDead
        )

        return TransferInfo(
            source: info.source,
            destination: info.destination,
            amount: info.amount,
            asset: info.asset,
            details: info.details,
            fees: info.fees,
            context: transferInfoContext.toContext()
        )
    }

    private func senderHasAssetsToSend(
        info: TransferInfo,
        availableBalance: Decimal,
        metadata: TransferMetaData
    ) -> Bool {
        var spendingAmount = info.amount.decimalValue

        let context = TransferMetadataContext(context: metadata.context ?? [:])

        if context.utilityMatchesAsset {
            spendingAmount = info.fees.reduce(spendingAmount) { result, fee in
                result + fee.value.decimalValue
            }
        }

        return availableBalance >= spendingAmount
    }

    private func senderHasAssetsToPayFee(
        info: TransferInfo,
        totalBalance: Decimal,
        metadata: TransferMetaData
    ) -> Bool {
        let totalFee: Decimal = info.fees.reduce(Decimal(0)) { result, fee in
            result + fee.value.decimalValue
        }

        let context = TransferMetadataContext(context: metadata.context ?? [:])

        let minBalance = context.utilityMinBalance ?? context.assetMinBalance

        let balance = context.utilityMatchesAsset ? totalBalance : (context.senderUtilityBalance ?? 0)

        return balance - totalFee >= minBalance
    }

    private func senderWillBeDead(
        info: TransferInfo,
        totalBalance: Decimal,
        metadata: TransferMetaData
    ) -> Bool {
        var spendingAmount = info.amount.decimalValue

        let context = TransferMetadataContext(context: metadata.context ?? [:])

        if context.utilityMatchesAsset {
            spendingAmount = info.fees.reduce(spendingAmount) { result, fee in
                result + fee.value.decimalValue
            }
        }

        return totalBalance - spendingAmount < context.assetMinBalance
    }

    private func receiverHasMainAccount(in metadata: TransferMetaData) -> Bool {
        let context = TransferMetadataContext(context: metadata.context ?? [:])

        if !context.utilityMatchesAsset {
            let receiverUtilityBalance = context.receiverUtilityBalance ?? 0
            let utilityMinBalance = context.utilityMinBalance ?? 0
            return receiverUtilityBalance >= utilityMinBalance
        } else {
            return true
        }
    }

    private func receiverCanReceive(amount: Decimal, metadata: TransferMetaData) -> Bool {
        let context = TransferMetadataContext(context: metadata.context ?? [:])

        return (context.receiverAssetBalance > 0) || (amount >= context.assetMinBalance)
    }
}
