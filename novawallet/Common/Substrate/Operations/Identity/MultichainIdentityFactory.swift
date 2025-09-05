import Foundation
import Operation_iOS
import SubstrateSdk

final class MultichainIdentityFactory {
    let chainIds: [ChainModel.Id]
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainIds: [ChainModel.Id],
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainIds = chainIds
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension MultichainIdentityFactory {
    func deriveFactories() -> [IdentityProxyFactoryProtocol] {
        chainIds.compactMap { chainId in
            do {
                let chain = try chainRegistry.getChainOrError(for: chainId)

                let requestFactory = StorageRequestFactory(
                    remoteFactory: StorageKeyFactory(),
                    operationManager: OperationManager(operationQueue: operationQueue)
                )

                let identityFactory = IdentityOperationFactory(requestFactory: requestFactory)

                return IdentityProxyFactory(
                    originChain: chain,
                    chainRegistry: chainRegistry,
                    identityOperationFactory: identityFactory
                )
            } catch {
                logger.warning("Identity chain skipped: \(error)")
                return nil
            }
        }
    }

    private func createMappingOperation<K: Hashable>(
        dependingOn wrappers: [CompoundOperationWrapper<[K: AccountIdentity]>],
        logger: LoggerProtocol
    ) -> BaseOperation<[K: AccountIdentity]> {
        ClosureOperation<[K: AccountIdentity]> {
            // prefer first found identity as chains are provided by priority
            // also ignore errors as for some chains fetch might fail
            wrappers.reduce(into: [K: AccountIdentity]()) { accum, nextWrapper in
                do {
                    let nextResult = try nextWrapper.targetOperation.extractNoCancellableResultData()
                    accum.merge(nextResult) { oldIdentity, _ in oldIdentity }
                } catch {
                    logger.warning("Identity fetch failed: \(error)")
                }
            }
        }
    }

    func createCommonWrapper<K: Hashable>(
        from wrappers: [CompoundOperationWrapper<[K: AccountIdentity]>]
    ) -> CompoundOperationWrapper<[K: AccountIdentity]> {
        let mappingOperation = createMappingOperation(dependingOn: wrappers, logger: logger)

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension MultichainIdentityFactory: IdentityProxyFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let factories = deriveFactories()

        guard !factories.isEmpty else {
            return .createWithResult([:])
        }

        let wrappers = factories.map { $0.createIdentityWrapper(for: accountIdClosure) }

        return createCommonWrapper(from: wrappers)
    }

    func createIdentityWrapperByAccountId(
        for accountIdClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        let factories = deriveFactories()

        guard !factories.isEmpty else {
            return .createWithResult([:])
        }

        let wrappers = factories.map { $0.createIdentityWrapperByAccountId(for: accountIdClosure) }

        return createCommonWrapper(from: wrappers)
    }
}
