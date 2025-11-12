import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol WalletRemoteQueryWrapperFactoryProtocol {
    func queryBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance>
}

enum WalletRemoteQueryWrapperFactoryError: Error {
    case unsupported
    case unexpectedBalanceValue
}

final class WalletRemoteQueryWrapperFactory {
    let requestFactory: StorageRequestFactoryProtocol
    let erc20QueryMessageFactory: EvmQueryContractMessageFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        erc20QueryMessageFactory: EvmQueryContractMessageFactoryProtocol = EvmQueryContractMessageFactory(),
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.erc20QueryMessageFactory = erc20QueryMessageFactory
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

// MARK: - Private

private extension WalletRemoteQueryWrapperFactory {
    func queryNativeBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
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
        } catch {
            return .createWithError(error)
        }
    }

    private func queryAssetsAccountBalance(
        for accountId: AccountId,
        extras: StatemineAssetExtras,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
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
        extras: StatemineAssetExtras,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
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
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)

            let accountWrapper = queryAssetsAccountBalance(
                for: accountId,
                extras: extras,
                connection: connection,
                runtimeProvider: runtimeProvider
            )

            let assetDetailsWrapper = queryAssetsDetailsBalance(
                extras: extras,
                connection: connection,
                runtimeProvider: runtimeProvider
            )

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
        } catch {
            return .createWithError(error)
        }
    }

    func queryOrmlBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        currencyId: Data
    ) -> CompoundOperationWrapper<AssetBalance> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)
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
        } catch {
            return .createWithError(error)
        }
    }

    func queryOrmlHydrationEvmBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        OrmlHydrationEvmWalletQueryFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        ).queryBalanceWrapper(
            for: accountId,
            chainAssetId: chainAsset.chainAssetId
        )
    }

    func queryEquilibriumBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        eqAssetId: EquilibriumAssetId
    ) -> CompoundOperationWrapper<AssetBalance> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)
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
        } catch {
            return .createWithError(error)
        }
    }

    func queryEvmBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        let operation = AsyncClosureOperation<AssetBalance> { completion in
            let params = EvmBalanceMessage.Params(
                holder: try accountId.toAddress(using: chainAsset.chain.chainFormat),
                block: .latest
            )

            try self.queryEvmBalance(
                for: accountId,
                chainAsset: chainAsset,
                with: params,
                method: EvmBalanceMessage.method,
                completion: completion
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func queryERC20Balance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        contractId: AccountId
    ) -> CompoundOperationWrapper<AssetBalance> {
        let operation = AsyncClosureOperation<AssetBalance> { completion in
            let params = try self.erc20QueryMessageFactory.erc20Balance(
                of: try accountId.toAddress(using: chainAsset.chain.chainFormat),
                contractAddress: try contractId.toAddress(using: chainAsset.chain.chainFormat)
            )

            try self.queryEvmBalance(
                for: accountId,
                chainAsset: chainAsset,
                with: params,
                method: EvmQueryMessage.method,
                completion: completion
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func queryEvmBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        with params: Encodable,
        method: String,
        completion: @escaping (Result<AssetBalance, Error>) -> Void
    ) throws {
        let connection = try chainRegistry.getConnectionOrError(for: chainAsset.chain.chainId)

        _ = try connection.callMethod(
            method,
            params: params,
            options: .init(resendOnReconnect: true)
        ) { (result: Result<String, Error>) in
            switch result {
            case let .success(balanceString):
                guard let balanceValue = BigUInt.fromHexString(balanceString) else {
                    completion(.failure(WalletRemoteQueryWrapperFactoryError.unexpectedBalanceValue))
                    return
                }
                let balance = AssetBalance(
                    evmBalance: balanceValue,
                    accountId: accountId,
                    chainAssetId: chainAsset.chainAssetId
                )

                completion(.success(balance))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - WalletRemoteQueryWrapperFactoryProtocol

extension WalletRemoteQueryWrapperFactory: WalletRemoteQueryWrapperFactoryProtocol {
    func queryBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        do {
            return try CustomAssetMapper(
                type: chainAsset.asset.type,
                typeExtras: chainAsset.asset.typeExtras
            ).mapAssetWithExtras(
                .init(
                    nativeHandler: {
                        self.queryNativeBalance(
                            for: accountId,
                            chainAsset: chainAsset
                        )
                    },
                    statemineHandler: { extras in
                        self.queryAssetsBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            extras: extras
                        )
                    },
                    ormlHandler: { extras in
                        do {
                            let currencyId = try Data(hexString: extras.currencyIdScale)
                            return self.queryOrmlBalance(for: accountId, chainAsset: chainAsset, currencyId: currencyId)
                        } catch {
                            return CompoundOperationWrapper.createWithError(error)
                        }
                    },
                    ormlHydrationEvmHandler: { _ in
                        self.queryOrmlHydrationEvmBalance(
                            for: accountId,
                            chainAsset: chainAsset
                        )
                    },
                    evmHandler: { contractId in
                        self.queryERC20Balance(
                            for: accountId,
                            chainAsset: chainAsset,
                            contractId: contractId
                        )
                    },
                    evmNativeHandler: {
                        self.queryEvmBalance(
                            for: accountId,
                            chainAsset: chainAsset
                        )
                    },
                    equilibriumHandler: { extras in
                        self.queryEquilibriumBalance(
                            for: accountId,
                            chainAsset: chainAsset,
                            eqAssetId: extras.assetId
                        )
                    }
                )
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
