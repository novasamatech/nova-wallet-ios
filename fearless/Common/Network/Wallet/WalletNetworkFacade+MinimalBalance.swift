import RobinHood
import BigInt
import CommonWallet

extension WalletNetworkFacade {
    func fetchMinimalBalanceOperation(
        for assets: [WalletAsset]
    ) -> CompoundOperationWrapper<[String: BigUInt]> {
        let wrappers: [String: CompoundOperationWrapper<BigUInt>] = assets.reduce(
            into: [:]
        ) { result, asset in
            guard
                let chainAssetId = ChainAssetId(walletId: asset.identifier),
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainAssetId.chainId) else {
                return
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

            let wrapper = CompoundOperationWrapper(
                targetOperation: constOperation,
                dependencies: [codingFactoryOperation]
            )

            result[asset.identifier] = wrapper
        }

        let mappingOperation = ClosureOperation<[String: BigUInt]> {
            try wrappers.mapValues { try $0.targetOperation.extractNoCancellableResultData() }
        }

        wrappers.values.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.values.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }
}
