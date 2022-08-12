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
    case invalidSender
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
        _: TransferMetadataInfo
    ) -> CompoundOperationWrapper<TransferMetaData?> {
        CompoundOperationWrapper<TransferMetaData?>.createWithResult(nil)
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

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            let coderFactory = try coderFactoryOperation.extractNoCancellableResultData()
            let maybeBuilder = try self?.addingTransferCall(
                to: builder,
                for: receiver,
                amount: amount,
                asset: remoteAsset,
                coderFactory: coderFactory
            )

            return maybeBuilder ?? builder
        }

        let signer = SigningWrapperFactory(keystore: keystore).createSigningWrapper(
            for: metaAccount.metaId,
            accountResponse: selectedAccount
        )

        let extrinsicFactory = ExtrinsicOperationFactory(
            accountId: selectedAccount.accountId,
            chain: chain,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection
        )

        let wrapper = extrinsicFactory.submit(builderClosure, signer: signer)
        wrapper.addDependency(operations: [coderFactoryOperation])

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try wrapper.targetOperation.extractNoCancellableResultData()
            return try Data(hexString: hashString)
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [coderFactoryOperation] + wrapper.allOperations
        )
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
