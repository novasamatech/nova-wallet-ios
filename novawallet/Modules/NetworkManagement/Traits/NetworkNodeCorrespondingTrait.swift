import Foundation
import Operation_iOS
import SubstrateSdk

protocol NetworkNodeCorrespondingTrait {
    var blockHashOperationFactory: BlockHashOperationFactoryProtocol { get }
}

extension NetworkNodeCorrespondingTrait {
    func substrateChainCorrespondingOperation(
        connection: JSONRPCEngine,
        node _: ChainNodeModel,
        chain: ChainNodeConnectable
    ) -> CompoundOperationWrapper<String> {
        let genesisBlockOperation = blockHashOperationFactory.createBlockHashOperation(
            connection: connection,
            for: { 0 }
        )

        let checkChainCorrespondingOperation = ClosureOperation<String> {
            let genesisHash = try genesisBlockOperation
                .extractNoCancellableResultData()
                .withoutHexPrefix()

            guard genesisHash == chain.chainId else {
                throw NetworkNodeCorrespondingError(networkName: chain.name)
            }

            return genesisHash
        }

        checkChainCorrespondingOperation.addDependency(genesisBlockOperation)

        return CompoundOperationWrapper(
            targetOperation: checkChainCorrespondingOperation,
            dependencies: [genesisBlockOperation]
        )
    }

    func evmChainCorrespondingOperation(
        connection: JSONRPCEngine,
        node _: ChainNodeModel,
        chain: ChainNodeConnectable
    ) -> CompoundOperationWrapper<String> {
        let chainIdOperation = EvmWebSocketOperationFactory(
            connection: connection,
            timeout: 10
        ).createChainIdOperation()

        let checkChainCorrespondingOperation = ClosureOperation<String> {
            let actualChainId = try chainIdOperation.extractNoCancellableResultData()

            guard actualChainId.wrappedValue == chain.addressPrefix else {
                throw NetworkNodeCorrespondingError(networkName: chain.name)
            }

            return Caip2.RegisteredChain.eip155(id: actualChainId.wrappedValue).rawChainId
        }

        checkChainCorrespondingOperation.addDependency(chainIdOperation)

        return CompoundOperationWrapper(
            targetOperation: checkChainCorrespondingOperation,
            dependencies: [chainIdOperation]
        )
    }
}

// MARK: Errors

struct NetworkNodeCorrespondingError: Error {
    let networkName: String
}

extension NetworkNodeCorrespondingError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        ErrorContent(
            title: R.string.localizable.networkNodeAddAlertWrongNetworkTitle(
                preferredLanguages: locale?.rLanguages
            ),
            message: R.string.localizable.networkNodeAddAlertWrongNetworkMessage(
                networkName,
                networkName,
                preferredLanguages: locale?.rLanguages
            )
        )
    }
}
