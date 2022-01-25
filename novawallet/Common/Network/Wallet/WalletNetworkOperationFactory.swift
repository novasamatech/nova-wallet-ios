import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import SubstrateSdk
import SoraKeystore

final class WalletNetworkOperationFactory {
    let metaAccount: MetaAccountModel
    let chains: [ChainModel.Id: ChainModel]
    let accountSettings: WalletAccountSettingsProtocol
    let chainRegistry: ChainRegistryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageRequestFactory: LocalStorageRequestFactoryProtocol
    let keystore: KeystoreProtocol

    init(
        metaAccount: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        accountSettings: WalletAccountSettingsProtocol,
        chainRegistry: ChainRegistryProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        localStorageRequestFactory: LocalStorageRequestFactoryProtocol,
        keystore: KeystoreProtocol
    ) {
        self.metaAccount = metaAccount
        self.chains = chains
        self.chainRegistry = chainRegistry
        self.accountSettings = accountSettings
        self.requestFactory = requestFactory
        self.chainStorage = chainStorage
        self.localStorageRequestFactory = localStorageRequestFactory
        self.keystore = keystore
    }

    func createAssetBalanceFetchOperation(
        _ accountId: Data,
        chain: ChainModel,
        asset: AssetModel
    ) -> CompoundOperationWrapper<AssetBalance?> {
        if let rawType = asset.type, let assetType = AssetType(rawValue: rawType) {
            switch assetType {
            case .statemine:
                guard let extras = try? asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                    return CompoundOperationWrapper.createWithResult(nil)
                }

                return createStatemineFetchOperation(
                    accountId,
                    chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                    palletAssetId: extras.assetId
                )
            }
        } else {
            return createNativeFetchOperation(
                accountId,
                chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                chainFormat: chain.chainFormat
            )
        }
    }

    func createNativeFetchOperation(
        _ accountId: Data,
        chainAssetId: ChainAssetId,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<AssetBalance?> {
        guard let connection = chainRegistry.getConnection(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]>

        switch chainFormat {
        case .substrate:
            wrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: { [accountId] },
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                storagePath: StorageCodingPath.account
            )
        case .ethereum:
            wrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: { [accountId.map { StringScaleMapper(value: $0) }] },
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                storagePath: StorageCodingPath.account
            )
        }

        let mapOperation = ClosureOperation<AssetBalance?> {
            let maybeAccountInfo = try wrapper.targetOperation.extractNoCancellableResultData().first?.value

            return maybeAccountInfo.map { accountInfo in
                AssetBalance(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    freeInPlank: accountInfo.data.free,
                    reservedInPlank: accountInfo.data.reserved,
                    frozenInPlank: accountInfo.data.locked
                )
            }
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createStatemineFetchOperation(
        _ accountId: Data,
        chainAssetId: ChainAssetId,
        palletAssetId: UInt32
    ) -> CompoundOperationWrapper<AssetBalance?> {
        guard let connection = chainRegistry.getConnection(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AssetAccount>]> = requestFactory.queryItems(
            engine: connection,
            keyParams1: { [StringScaleMapper(value: palletAssetId)] },
            keyParams2: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.assetsAccount
        )

        let mapOperation = ClosureOperation<AssetBalance?> {
            let maybeAccountInfo = try wrapper.targetOperation.extractNoCancellableResultData().first?.value

            return maybeAccountInfo.map { accountInfo in
                AssetBalance(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    freeInPlank: accountInfo.balance,
                    reservedInPlank: 0,
                    frozenInPlank: 0
                )
            }
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func addingTransferCall(
        to builder: ExtrinsicBuilderProtocol,
        for receiver: AccountId,
        amount: BigUInt,
        asset: AssetModel
    ) throws -> ExtrinsicBuilderProtocol {
        let callFactory = SubstrateCallFactory()

        if let rawType = asset.type, let assetType = AssetType(rawValue: rawType) {
            switch assetType {
            case .statemine:
                guard let extras = try asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                    return builder
                }

                let call = callFactory.assetsTransfer(to: receiver, assetId: extras.assetId, amount: amount)
                return try builder.adding(call: call)
            }
        } else {
            let call = callFactory.nativeTransfer(to: receiver, amount: amount)
            return try builder.adding(call: call)
        }
    }
}
