import Foundation
import CommonWallet
import RobinHood
import xxHash_Swift
import SubstrateSdk
import IrohaCrypto
import Starscream
import BigInt

enum WalletNetworkOperationFactoryError: Error {
    case invalidAmount
    case invalidAsset
    case invalidChain
    case invalidReceiver
}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        CompoundOperationWrapper<[BalanceData]?>.createWithResult(nil)
    }

    func fetchTransactionHistoryOperation(
        _: WalletHistoryRequest,
        pagination _: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let operation = ClosureOperation<AssetTransactionPageData?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func transferMetadataOperation(
        _ info: TransferMetadataInfo
    ) -> CompoundOperationWrapper<TransferMetaData?> {
        guard
            let chainAssetId = ChainAssetId(walletId: info.assetId),
            let asset = accountSettings.assets.first(where: { $0.identifier == info.assetId }),
            let chain = chains[chainAssetId.chainId],
            let transferAsset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
            let feeAsset = chain.utilityAssets().first,
            let selectedAccount = metaAccount.fetch(for: chain.accountRequest()),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let amount = Decimal(1.0).toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let receiver = try? Data(hexString: info.receiver) else {
            let error = WalletNetworkOperationFactoryError.invalidReceiver
            return CompoundOperationWrapper.createWithError(error)
        }

        let compoundReceiver = createAssetBalanceFetchOperation(
            receiver,
            chain: chain,
            asset: transferAsset
        )

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            let maybeBuilder = try self?.addingTransferCall(
                to: builder,
                for: receiver,
                amount: amount,
                asset: transferAsset
            )

            return maybeBuilder ?? builder
        }

        let extrinsicFactory = ExtrinsicOperationFactory(
            accountId: selectedAccount.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection
        )

        let infoWrapper = extrinsicFactory.estimateFeeOperation(builderClosure)

        let priceOperation: CompoundOperationWrapper<[PriceData]?>

        let priceIds = [transferAsset, feeAsset].reduce(
            into: [AssetModel.PriceId]()
        ) { result, asset in
            if let priceId = asset.priceId, !result.contains(priceId) {
                result.append(priceId)
            }
        }

        if !priceIds.isEmpty {
            priceOperation = CoingeckoPriceListSource(priceIds: priceIds).fetchOperation()
        } else {
            priceOperation = CompoundOperationWrapper.createWithResult(nil)
        }

        let mapOperation: ClosureOperation<TransferMetaData?> = ClosureOperation {
            let paymentInfo = try infoWrapper.targetOperation.extractNoCancellableResultData()
            let priceDataList = try priceOperation.targetOperation.extractNoCancellableResultData()

            guard let fee = BigUInt(paymentInfo.fee),
                  let decimalFee = Decimal.fromSubstrateAmount(
                      fee,
                      precision: Int16(bitPattern: feeAsset.precision)
                  )
            else {
                return nil
            }

            let assetPrice: Decimal = {
                if transferAsset.priceId != nil, let priceData = priceDataList?.first {
                    return Decimal(string: priceData.price) ?? .zero
                } else {
                    return .zero
                }
            }()

            let feePrice: Decimal = {
                if feeAsset.priceId != nil, let priceData = priceDataList?.last {
                    return Decimal(string: priceData.price) ?? .zero
                } else {
                    return .zero
                }
            }()

            let amount = AmountDecimal(value: decimalFee)

            let feeDescription = FeeDescription(
                identifier: asset.identifier,
                assetId: asset.identifier,
                type: FeeType.fixed.rawValue,
                parameters: [amount],
                context: FeeMetadataContext(feeAssetBalance: 0, feeAssetPrice: feePrice).toContext()
            )

            if let receiverInfo = try compoundReceiver.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {
                let context = TransferMetadataContext(
                    assetBalance: receiverInfo,
                    precision: asset.precision,
                    transferAssetPrice: assetPrice
                ).toContext()
                return TransferMetaData(feeDescriptions: [feeDescription], context: context)
            } else {
                return TransferMetaData(feeDescriptions: [feeDescription])
            }
        }

        let dependencies = compoundReceiver.allOperations + infoWrapper.allOperations + priceOperation.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard
            let chainAssetId = ChainAssetId(walletId: info.asset),
            let asset = accountSettings.assets.first(where: { $0.identifier == info.asset }),
            let chain = chains[chainAssetId.chainId],
            let remoteAsset = chain.assets.first(where: { $0.assetId == chainAssetId.assetId }),
            let selectedAccount = metaAccount.fetch(for: chain.accountRequest()),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let amount = info.amount.decimalValue.toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let receiver = try? Data(hexString: info.destination) else {
            let error = WalletNetworkOperationFactoryError.invalidReceiver
            return CompoundOperationWrapper.createWithError(error)
        }

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            let maybeBuilder = try self?.addingTransferCall(
                to: builder,
                for: receiver,
                amount: amount,
                asset: remoteAsset
            )

            return maybeBuilder ?? builder
        }

        let signer = SigningWrapper(
            keystore: keystore,
            metaId: metaAccount.metaId,
            accountResponse: selectedAccount
        )

        let extrinsicFactory = ExtrinsicOperationFactory(
            accountId: selectedAccount.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection
        )

        let wrapper = extrinsicFactory.submit(builderClosure, signer: signer)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try wrapper.targetOperation.extractNoCancellableResultData()
            return try Data(hexString: hashString)
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func searchOperation(_: String) -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper<[SearchData]?>.createWithResult(nil)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper<[SearchData]?>.createWithResult(nil)
    }

    func withdrawalMetadataOperation(
        _: WithdrawMetadataInfo
    ) -> CompoundOperationWrapper<WithdrawMetaData?> {
        CompoundOperationWrapper<WithdrawMetaData?>.createWithResult(nil)
    }

    func withdrawOperation(_: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper<Data>.createWithResult(Data())
    }
}
