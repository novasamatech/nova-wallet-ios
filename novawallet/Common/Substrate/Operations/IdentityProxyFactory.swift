import Foundation
import Operation_iOS

protocol IdentityProxyFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]>

    func createIdentityWrapperByAccountId(
        for accountIdClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]>
}

final class IdentityProxyFactory {
    let originChain: ChainModel
    let chainRegistry: ChainRegistryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol

    init(
        originChain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.originChain = originChain
        self.chainRegistry = chainRegistry
        self.identityOperationFactory = identityOperationFactory
    }

    private func deriveIdentityParams() throws -> IdentityChainParams {
        let identityChainId = originChain.identityChain ?? originChain.chainId

        let connection = try chainRegistry.getConnectionOrError(for: identityChainId)

        let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: identityChainId)

        return .init(connection: connection, runtimeService: runtimeService)
    }
}

extension IdentityProxyFactory: IdentityProxyFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        do {
            let params = try deriveIdentityParams()

            return identityOperationFactory.createIdentityWrapper(
                for: accountIdClosure,
                identityChainParams: params,
                originChainFormat: originChain.chainFormat
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createIdentityWrapperByAccountId(
        for accountIdClosure: @escaping () throws -> [AccountId]
    ) -> CompoundOperationWrapper<[AccountId: AccountIdentity]> {
        do {
            let params = try deriveIdentityParams()

            return identityOperationFactory.createIdentityWrapperByAccountId(
                for: accountIdClosure,
                identityChainParams: params,
                originChainFormat: originChain.chainFormat
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
