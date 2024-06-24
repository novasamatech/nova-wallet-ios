import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class ExtrinsicProofGenerationTests: XCTestCase {
    
    func testKusamaProofGeneration() {
        do {
            let proof = try performTransferProofGeneration(for: KnowChainId.kusama)
            
            Logger.shared.info("Kusama info proof: \(proof)")
        } catch {
            XCTFail("Unexpected Kusama error: \(error)")
        }
    }

    private func performTransferProofGeneration(for chainId: ChainModel.Id) throws -> Data {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let operationQueue = OperationQueue()
        
        let runtimeRepositoryFactory = RuntimeMetadataRepositoryFactory(storageFacade: storageFacade)
        
        let extrinsicProofFactory = ExtrinsicProofOperationFactory(
            metadataRepositoryFactory: runtimeRepositoryFactory
        )
        
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        
        let metadataHashFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: runtimeRepositoryFactory,
            operationQueue: operationQueue
        )
        
        let metadataHashWrapper = metadataHashFactory.createCheckMetadataHashWrapper(
            for: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )
        
        let extrinsicSigningParamsOperation = ClosureOperation<ExtrinsicSignatureParams> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            
            guard let metadataHash = try metadataHashWrapper.targetOperation.extractNoCancellableResultData() else {
                throw CommonError.undefined
            }
            
            let encoder = codingFactory.createEncoder()
            
            let callFactory = SubstrateCallFactory()
            let call = callFactory.nativeTransferAll(to: AccountId.zeroAccountId(of: 32))
            
            return try ExtrinsicBuilder(
                specVersion: codingFactory.specVersion,
                transactionVersion: codingFactory.txVersion,
                genesisHash: chainId
            )
            .with(metadataHash: metadataHash)
            .adding(call: call)
            .buildExtrinsicSignatureParams(
                encodingBy: encoder,
                metadata: codingFactory.metadata
            )
        }
        
        extrinsicSigningParamsOperation.addDependency(codingFactoryOperation)
        extrinsicSigningParamsOperation.addDependency(metadataHashWrapper.targetOperation)
        
        let proofWrapper = extrinsicProofFactory.createExtrinsicProofWrapper(
            for: chain,
            connection: connection
        ) {
            try extrinsicSigningParamsOperation.extractNoCancellableResultData()
        }
        
        proofWrapper.addDependency(operations: [extrinsicSigningParamsOperation])
        
        let operations = [codingFactoryOperation] + metadataHashWrapper.allOperations +
            [extrinsicSigningParamsOperation] + proofWrapper.allOperations
        operationQueue.addOperations(operations, waitUntilFinished: true)
        
        return try proofWrapper.targetOperation.extractNoCancellableResultData()
    }

}
