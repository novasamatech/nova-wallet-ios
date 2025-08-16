import Foundation
import Operation_iOS
import SubstrateSdk

protocol WalletRemoteQueryWrapperFactoryProtocol {
    func queryBalance(for accountId: AccountId, chainAsset: ChainAsset) -> CompoundOperationWrapper<AssetBalance>
}

enum WalletRemoteQueryWrapperFactoryError: Error {
    case unsupported
}

final class WalletRemoteQueryWrapperFactory {
    let requestFactory: StorageRequestFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        requestFactory: StorageRequestFactoryProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.requestFactory = requestFactory
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.operationQueue = operationQueue
    }

    func queryNativeBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: accountId)] },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: SystemPallet.accountPath
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<AssetBalance> {
            let accountInfo = try wrapper.targetOperation.extractNoCancellableResultData().first?.value

            return AssetBalance(
                accountInfo: accountInfo,
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId
            )
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation] + wrapper.allOperations
        )
    }

    private func queryAssetsAccountBalance(
        for accountId: AccountId,
        extras: StatemineAssetExtras
    ) -> CompoundOperationWrapper<[StorageResponse<PalletAssets.Account>]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let path = StorageCodingPath.assetsAccount(from: extras.palletName)

        let encodingOperation = DoubleMapKeyEncodingOperation<String, BytesCodable>(
            path: path,
            storageKeyFactory: StorageKeyFactory(),
            keyParams1: [extras.assetId],
            keyParams2: [BytesCodable(wrappedValue: accountId)],
            param1Encoder: StatemineAssetSerializer.subscriptionKeyEncoder(for: extras.assetId),
            param2Encoder: nil
        )

        encodingOperation.configurationBlock = {
            do {
                encodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        encodingOperation.addDependency(codingFactoryOperation)

        let wrapper: CompoundOperationWrapper<[StorageResponse<PalletAssets.Account>]> = requestFactory.queryItems(
            engine: connection,
            keys: { try encodingOperation.extractNoCancellableResultData() },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: path
        )

        wrapper.addDependency(operations: [codingFactoryOperation, encodingOperation])

        let dependencies = [codingFactoryOperation, encodingOperation] + wrapper.dependencies

        return CompoundOperationWrapper(targetOperation: wrapper.targetOperation, dependencies: dependencies)
    }

    private func queryAssetsDetailsBalance(
        extras: StatemineAssetExtras
    ) -> CompoundOperationWrapper<[StorageResponse<PalletAssets.Details>]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let path = StorageCodingPath.assetsDetails(from: extras.palletName)

        let encodingOperation = MapKeyEncodingOperation<String>(
            path: path,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [extras.assetId],
            paramEncoder: StatemineAssetSerializer.subscriptionKeyEncoder(for: extras.assetId)
        )

        encodingOperation.configurationBlock = {
            do {
                encodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        encodingOperation.addDependency(codingFactoryOperation)

        let wrapper: CompoundOperationWrapper<[StorageResponse<PalletAssets.Details>]> = requestFactory.queryItems(
            engine: connection,
            keys: { try encodingOperation.extractNoCancellableResultData() },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: path
        )

        wrapper.addDependency(operations: [codingFactoryOperation, encodingOperation])

        let dependencies = [codingFactoryOperation, encodingOperation] + wrapper.dependencies

        return CompoundOperationWrapper(targetOperation: wrapper.targetOperation, dependencies: dependencies)
    }

    private func queryAssetsBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        extras: StatemineAssetExtras
    ) -> CompoundOperationWrapper<AssetBalance> {
        let accountWrapper = queryAssetsAccountBalance(for: accountId, extras: extras)

        let assetDetailsWrapper = queryAssetsDetailsBalance(extras: extras)

        let mappingOperation = ClosureOperation<AssetBalance> {
            let account = try accountWrapper.targetOperation.extractNoCancellableResultData().first?.value
            let assetDetails = try assetDetailsWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return AssetBalance(
                assetsAccount: account,
                assetsDetails: assetDetails,
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId
            )
        }

        mappingOperation.addDependency(assetDetailsWrapper.targetOperation)
        mappingOperation.addDependency(accountWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: accountWrapper.allOperations + assetDetailsWrapper.allOperations
        )
    }

    func queryOrmlBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        currencyId: Data
    ) -> CompoundOperationWrapper<AssetBalance> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let encodingOperation = DoubleMapKeyEncodingOperation<BytesCodable, BytesCodable>(
            path: .ormlTokenAccount,
            storageKeyFactory: StorageKeyFactory(),
            keyParams1: [BytesCodable(wrappedValue: accountId)],
            keyParams2: [BytesCodable(wrappedValue: currencyId)],
            param1Encoder: nil,
            param2Encoder: { $0.wrappedValue }
        )

        encodingOperation.configurationBlock = {
            do {
                encodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        encodingOperation.addDependency(codingFactoryOperation)

        let wrapper: CompoundOperationWrapper<[StorageResponse<OrmlAccount>]> = requestFactory.queryItems(
            engine: connection,
            keys: { try encodingOperation.extractNoCancellableResultData() },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: .ormlTokenAccount
        )

        wrapper.addDependency(operations: [codingFactoryOperation, encodingOperation])

        let mappingOperation = ClosureOperation<AssetBalance> {
            let account = try wrapper.targetOperation.extractNoCancellableResultData().first?.value

            return AssetBalance(
                ormlAccount: account,
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId
            )
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, encodingOperation] + wrapper.allOperations
        )
    }

    func queryOrmlHydrationEvmBalance(
        for _: AccountId,
        chainAsset _: ChainAsset,
        currencyId _: Data
    ) -> CompoundOperationWrapper<AssetBalance> {
        // TODO: GDOT Implement query
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }

    func queryEquilibriumBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        eqAssetId: EquilibriumAssetId
    ) -> CompoundOperationWrapper<AssetBalance> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let balancesWrapper: CompoundOperationWrapper<[StorageResponse<EquilibriumAccountInfo>]>
        balancesWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: accountId)] },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: .equilibriumBalances
        )

        let reserveWrapper: CompoundOperationWrapper<[StorageResponse<EquilibriumReservedData>]>
        reserveWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams1: { [BytesCodable(wrappedValue: accountId)] },
            keyParams2: { [StringScaleMapper(value: eqAssetId)] },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: .equilibriumReserved
        )

        balancesWrapper.addDependency(operations: [codingFactoryOperation])
        reserveWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<AssetBalance> {
            let account = try balancesWrapper.targetOperation.extractNoCancellableResultData().first?.value
            let reserve = try reserveWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return AssetBalance(
                eqAccount: account,
                eqReserve: reserve,
                eqAssetId: eqAssetId,
                isUtilityAsset: chainAsset.isUtilityAsset,
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId
            )
        }

        mappingOperation.addDependency(balancesWrapper.targetOperation)
        mappingOperation.addDependency(reserveWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + balancesWrapper.allOperations + reserveWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension WalletRemoteQueryWrapperFactory: WalletRemoteQueryWrapperFactoryProtocol {
    func queryBalance(for accountId: AccountId, chainAsset: ChainAsset) -> CompoundOperationWrapper<AssetBalance> {
        do {
            return try CustomAssetMapper(
                type: chainAsset.asset.type,
                typeExtras: chainAsset.asset.typeExtras
            ).mapAssetWithExtras(
                .init(
                    nativeHandler: {
                        self.queryNativeBalance(for: accountId, chainAsset: chainAsset)
                    },
                    statemineHandler: { extras in
                        self.queryAssetsBalance(for: accountId, chainAsset: chainAsset, extras: extras)
                    },
                    ormlHandler: { extras in
                        do {
                            let currencyId = try Data(hexString: extras.currencyIdScale)
                            return self.queryOrmlBalance(for: accountId, chainAsset: chainAsset, currencyId: currencyId)
                        } catch {
                            return CompoundOperationWrapper.createWithError(error)
                        }
                    },
                    ormlHydrationEvmHandler: { extras in
                        do {
                            let currencyId = try Data(hexString: extras.currencyIdScale)
                            return self.queryOrmlHydrationEvmBalance(
                                for: accountId,
                                chainAsset: chainAsset,
                                currencyId: currencyId
                            )
                        } catch {
                            return CompoundOperationWrapper.createWithError(error)
                        }
                    },
                    evmHandler: { _ in
                        CompoundOperationWrapper.createWithError(WalletRemoteQueryWrapperFactoryError.unsupported)
                    },
                    evmNativeHandler: {
                        CompoundOperationWrapper.createWithError(WalletRemoteQueryWrapperFactoryError.unsupported)
                    },
                    equilibriumHandler: { extras in
                        self.queryEquilibriumBalance(for: accountId, chainAsset: chainAsset, eqAssetId: extras.assetId)
                    }
                )
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
