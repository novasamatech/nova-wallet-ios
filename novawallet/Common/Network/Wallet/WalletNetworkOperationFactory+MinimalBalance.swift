import RobinHood
import BigInt
import CommonWallet

extension WalletNetworkOperationFactory {
    func fetchMinimalBalanceOperation(
        for chainAssets: [ChainAsset]
    ) -> CompoundOperationWrapper<[ChainAssetId: BigUInt]> {
        let wrappers: [ChainAssetId: CompoundOperationWrapper<BigUInt>] = chainAssets.reduce(
            into: [:]
        ) { result, chainAsset in

            let chain = chainAsset.chain
            let asset = chainAsset.asset
            let assetId = chainAsset.chainAssetId

            if let rawType = asset.type {
                switch AssetType(rawValue: rawType) {
                case .statemine:
                    result[assetId] = createStateminMinimalBalanceOperation(
                        from: chain,
                        asset: asset
                    )
                case .orml:
                    result[assetId] = createOrmlMinimalBalanceOperation(from: chain, asset: asset)
                case .none:
                    result[assetId] = CompoundOperationWrapper.createWithResult(0)
                }
            } else {
                result[assetId] = createNativeMinimalBalanceOperation(from: chain, asset: asset)
            }
        }

        let mappingOperation = ClosureOperation<[ChainAssetId: BigUInt]> {
            try wrappers.mapValues { try $0.targetOperation.extractNoCancellableResultData() }
        }

        wrappers.values.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.values.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }

    private func createNativeMinimalBalanceOperation(
        from chain: ChainModel,
        asset _: AssetModel
    ) -> CompoundOperationWrapper<BigUInt> {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<BigUInt>(path: .existentialDeposit)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: constOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    private func createStateminMinimalBalanceOperation(
        from chain: ChainModel,
        asset: AssetModel
    ) -> CompoundOperationWrapper<BigUInt> {
        guard
            let extras = try? asset.typeExtras?.map(to: StatemineAssetExtras.self),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let localKey = try? LocalStorageKeyFactory().createFromStoragePath(
                .assetsDetails,
                encodableElement: extras.assetId,
                chainId: chain.chainId
            ) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<LocalStorageResponse<AssetDetails>> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                key: { localKey },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .assetsDetails, shouldFallback: false)
            )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<BigUInt> {
            let details = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            return details.value?.minBalance ?? 0
        }

        let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    private func createOrmlMinimalBalanceOperation(
        from _: ChainModel,
        asset: AssetModel
    ) -> CompoundOperationWrapper<BigUInt> {
        if let extras = try? asset.typeExtras?.map(to: OrmlTokenExtras.self) {
            let minBalance = BigUInt(extras.existentialDeposit) ?? 0
            return CompoundOperationWrapper.createWithResult(minBalance)
        } else {
            return CompoundOperationWrapper.createWithResult(0)
        }
    }
}
