import Foundation
import CommonWallet
import IrohaCrypto
import BigInt
import SubstrateSdk

extension TransactionHistoryItem {
    static func createFromTransferInfo(
        _ info: TransferInfo,
        senderAccount: ChainAccountResponse,
        transactionHash: Data,
        chainAsset: ChainAsset,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> TransactionHistoryItem {
        let senderAccountId = senderAccount.accountId
        let receiverAccountId = try Data(hexString: info.destination)

        let chainAssetInfo = chainAsset.chainAssetInfo
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        let sender = try senderAccountId.toAddress(using: chainAssetInfo.chain)

        let receiver = try receiverAccountId.toAddress(using: chainAssetInfo.chain)

        guard let amount = info.amount.decimalValue
            .toSubstrateAmount(precision: chainAssetInfo.asset.assetPrecision) else {
            throw AmountDecimalError.invalidStringValue
        }

        let (encodedCall, callPath) = try encodeCallForReceiver(
            receiverAccountId,
            amount: amount,
            asset: chainAsset.asset,
            coderFactory: codingFactory
        )

        let totalFee = info.fees.reduce(Decimal(0)) { total, fee in total + fee.value.decimalValue }

        guard let feeValue = totalFee.toSubstrateAmount(
            precision: chainAssetInfo.asset.assetPrecision
        ) else {
            throw AmountDecimalError.invalidStringValue
        }

        let timestamp = Int64(Date().timeIntervalSince1970)

        return TransactionHistoryItem(
            chainId: chain.chainId,
            assetId: asset.assetId,
            sender: sender,
            receiver: receiver,
            amountInPlank: String(amount),
            status: .pending,
            txHash: transactionHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: String(feeValue),
            blockNumber: nil,
            txIndex: nil,
            callPath: callPath,
            call: encodedCall
        )
    }

    private static func encodeCallForReceiver(
        _ receiver: AccountId,
        amount: BigUInt,
        asset: AssetModel,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> (Data, CallCodingPath) {
        if let rawType = asset.type, let assetType = AssetType(rawValue: rawType) {
            switch assetType {
            case .statemine:
                guard let typeExtras = try asset.typeExtras?.map(
                    to: StatemineAssetExtras.self,
                    with: coderFactory.createRuntimeJsonContext().toRawContext()
                ) else {
                    throw CommonError.undefined
                }

                let callPath = CallCodingPath.assetsTransfer
                let callArgs = AssetsTransfer(
                    assetId: typeExtras.assetId,
                    target: .accoundId(receiver),
                    amount: amount
                )

                let call = RuntimeCall(
                    moduleName: callPath.moduleName,
                    callName: callPath.callName,
                    args: callArgs
                )

                let encodedCall = try JSONEncoder.scaleCompatible(
                    with: coderFactory.createRuntimeJsonContext().toRawContext()
                ).encode(call)

                return (encodedCall, callPath)

            case .orml:
                guard let typeExtras = try asset.typeExtras?.map(
                    to: OrmlTokenExtras.self,
                    with: coderFactory.createRuntimeJsonContext().toRawContext()
                ) else {
                    throw CommonError.undefined
                }

                let callPath: CallCodingPath
                if coderFactory.metadata.getCall(
                    from: CallCodingPath.tokensTransfer.moduleName,
                    with: CallCodingPath.tokensTransfer.callName
                ) != nil {
                    callPath = CallCodingPath.tokensTransfer
                } else {
                    callPath = CallCodingPath.currenciesTransfer
                }

                let currencyIdData = try Data(hexString: typeExtras.currencyIdScale)
                let decoder = try coderFactory.createDecoder(from: currencyIdData)
                let currencyId = try decoder.read(type: typeExtras.currencyIdType)

                let callArgs = OrmlTokenTransfer(
                    dest: .accoundId(receiver),
                    currencyId: currencyId,
                    amount: amount
                )

                let call = RuntimeCall(
                    moduleName: callPath.moduleName,
                    callName: callPath.callName,
                    args: callArgs
                )

                let encodedCall = try JSONEncoder.scaleCompatible(
                    with: coderFactory.createRuntimeJsonContext().toRawContext()
                ).encode(call)

                return (encodedCall, callPath)
            }
        } else {
            let callPath = CallCodingPath.transfer
            let callArgs = TransferCall(dest: .accoundId(receiver), value: amount)
            let call = RuntimeCall<TransferCall>(
                moduleName: callPath.moduleName,
                callName: callPath.callName,
                args: callArgs
            )
            let encodedCall = try JSONEncoder.scaleCompatible(
                with: coderFactory.createRuntimeJsonContext().toRawContext()
            ).encode(call)

            return (encodedCall, callPath)
        }
    }
}

extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
