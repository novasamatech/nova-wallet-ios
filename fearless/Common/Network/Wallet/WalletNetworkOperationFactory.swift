import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import FearlessUtils
import SoraKeystore

final class WalletNetworkOperationFactory {
    let metaAccount: MetaAccountModel
    let chains: [ChainModel.Id: ChainModel]
    let accountSettings: WalletAccountSettingsProtocol
    let chainRegistry: ChainRegistryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let keystore: KeystoreProtocol

    init(
        metaAccount: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        accountSettings: WalletAccountSettingsProtocol,
        chainRegistry: ChainRegistryProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        keystore: KeystoreProtocol
    ) {
        self.metaAccount = metaAccount
        self.chains = chains
        self.chainRegistry = chainRegistry
        self.accountSettings = accountSettings
        self.requestFactory = requestFactory
        self.chainStorage = chainStorage
        self.keystore = keystore
    }

    func createAccountInfoFetchOperation(
        _ accountId: Data,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<AccountInfo?> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
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

        let mapOperation = ClosureOperation<AccountInfo?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
