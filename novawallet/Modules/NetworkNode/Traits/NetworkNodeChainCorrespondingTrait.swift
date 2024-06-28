import Operation_iOS
import SubstrateSdk

protocol NetworkNodeChainCorrespondingTrait {
    var blockHashOperationFactory: BlockHashOperationFactoryProtocol { get }
}

extension NetworkNodeChainCorrespondingTrait {
    func substrateChainCorrespondingOperation(
        connection: JSONRPCEngine,
        node: ChainNodeModel,
        chain: ChainModel
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
                throw NetworkNodeBaseInteractorError.wrongNetwork(networkName: chain.name)
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
        node: ChainNodeModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<String> {
        let chainIdOperation = EvmWebSocketOperationFactory(
            connection: connection,
            timeout: 10
        ).createChainIdOperation()
        
        let checkChainCorrespondingOperation = ClosureOperation<String> {
            let actualChainId = try chainIdOperation.extractNoCancellableResultData()
            
            guard actualChainId.wrappedValue == chain.addressPrefix else {
                throw NetworkNodeBaseInteractorError.wrongNetwork(networkName: chain.name)
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
