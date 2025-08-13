import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class ExtrinsicProofGenerationTests: XCTestCase {
    
    func testKusamaProofGeneration() {
        do {
            let proof = try performTransferProofGeneration(for: KnowChainId.kusama)
            
            Logger.shared.info("Kusama info proof: \(proof.toHexWithPrefix())")
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
            
            let callFactory = SubstrateCallFactory()
            let call = callFactory.nativeTransfer(
                to: AccountId.random(of: 32)!,
                amount: 230000000000,
                callPath: CallCodingPath.transferAllowDeath
            )
            
            let customExtensions = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions()
            
            var builder = try ExtrinsicBuilder(
                specVersion: codingFactory.specVersion,
                transactionVersion: codingFactory.txVersion,
                genesisHash: chainId
            )
            .with(runtimeJsonContext: codingFactory.createRuntimeJsonContext())
            .with(metadataHash: metadataHash)
            .adding(call: call)
            
            for customExtension in customExtensions {
                builder = builder.adding(transactionExtension: customExtension)
            }
            
            let params = try builder.buildExtrinsicSignatureParams(
                encodingFactory: codingFactory,
                metadata: codingFactory.metadata
            )
            
            Logger.shared.info("Metadata hash: \(metadataHash.toHexString())")
            Logger.shared.info("Call: \(params.encodedCall.toHexString())")
            Logger.shared.info("Include in extrinsic: \(params.includedInExtrinsicExtra.toHexString())")
            Logger.shared.info("Include in signature: \(params.includedInSignatureExtra.toHexString())")
            
            return params
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
