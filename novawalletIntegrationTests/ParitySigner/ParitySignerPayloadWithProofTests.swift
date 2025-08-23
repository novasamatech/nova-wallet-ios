import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class ParitySignerPayloadWithProofTests: XCTestCase {
    struct PayloadWithProof {
        let signingPayload: Data
        let proof: Data
    }
    
    func testWestendTransferGeneration() {
        do {
            let message = try createSignerMessage(
                for: KnowChainId.westend,
                account: "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
            ) { builder in
                
                let dest = try "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty".toAccountId()
                let transferCall = RuntimeCall(
                    moduleName: BalancesPallet.name,
                    callName: "transfer_keep_alive",
                    args: TransferCall(
                        dest: .accoundId(dest),
                        value: Balance(100000000)
                    )
                )
                
                return try builder
                    .with(
                        era: .mortal(period: 64, phase: 61),
                        blockHash: "98a8ee9e389043cd8a9954b254d822d34138b9ae97d3b7f50dc6781b13df8d84"
                    )
                    .with(tip: 10000000)
                    .with(nonce: 261)
                    .adding(call: transferCall)
            }
            
            Logger.shared.info("Westend payload: \(message.toHexWithPrefix())")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testWestendStakingGeneration() {
        do {
            let message = try createSignerMessage(
                for: KnowChainId.westend,
                account: "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
            ) { builder in
                let bondCall = RuntimeCall(
                    moduleName: Staking.Bond.path.moduleName,
                    callName: Staking.Bond.path.callName,
                    args: Staking.Bond.V2(
                        value: 1061900000000,
                        payee: .staked
                    )
                )
                
                let validator1 = try "5CFPcUJgYgWryPaV1aYjSbTpbTLu42V32Ytw1L9rfoMAsfGh".toAccountId()
                let validator2 = try "5G1ojzh47Yt8KoYhuAjXpHcazvsoCXe3G8LZchKDvumozJJJ".toAccountId()
                let validator3 = try "5FZoQhgUCmqBxnkHX7jCqThScS2xQWiwiF61msg63CFL3Y8f".toAccountId()
                
                let nominateCall = RuntimeCall(
                    moduleName: "Staking",
                    callName: "nominate",
                    args: NominateCall(
                        targets: [
                            .accoundId(validator1),
                            .accoundId(validator2),
                            .accoundId(validator3)
                        ]
                    )
                )
                
                return try builder
                    .with(
                        era: .mortal(period: 64, phase: 5),
                        blockHash: "5b1d91c89d3de85a4d6eee76ecf3a303cf38b59e7d81522eb7cd24b02eb161ff"
                    )
                    .with(tip: 0)
                    .with(nonce: 2)
                    .adding(call: bondCall)
                    .adding(call: nominateCall)
            }
            
            Logger.shared.info("Westend payload: \(message.toHexWithPrefix())")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testHydrationTransferGeneration() {
        do {
            let message = try createSignerMessage(
                for: KnowChainId.hydra,
                account: "15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"
            ) { builder in
                
                let dest = try "14E5nqKAp3oAJcmzgZhUD2RcptBeUBScxKHgJKU4HPNcKVf3".toAccountId()
                let transferCall = RuntimeCall(
                    moduleName: BalancesPallet.name,
                    callName: "transfer_keep_alive",
                    args: TransferCall(
                        dest: .accoundId(dest),
                        value: Balance(100000000)
                    )
                )
                
                return try builder
                    .with(
                        era: .mortal(period: 64, phase: 61),
                        blockHash: "98a8ee9e389043cd8a9954b254d822d34138b9ae97d3b7f50dc6781b13df8d84"
                    )
                    .with(tip: 10000000)
                    .with(nonce: 261)
                    .adding(call: transferCall)
            }
            
            Logger.shared.info("Hydration payload: \(message.toHexWithPrefix())")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testMythosTransferGeneration() {
        do {
            let message = try createSignerMessage(
                for: KnowChainId.mythos,
                account: "0xe9267b732a8e9c9444e46f3d04d4610a996d682d"
            ) { builder in
                
                let dest = try "0xe9267b732a8e9c9555e46f3d04d4610a996d682d".toAccountId()
                let transferCall = RuntimeCall(
                    moduleName: BalancesPallet.name,
                    callName: "transfer_keep_alive",
                    args: TransferCall(
                        dest: .accoundId(dest),
                        value: Balance(100000000)
                    )
                )
                
                return try builder
                    .with(
                        era: .mortal(period: 64, phase: 61),
                        blockHash: "98a8ee9e389043cd8a9954b254d822d34138b9ae97d3b7f50dc6781b13df8d84"
                    )
                    .with(tip: 10000000)
                    .with(nonce: 261)
                    .adding(call: transferCall)
            }
            
            Logger.shared.info("Hydration payload: \(message.toHexWithPrefix())")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    private func createSignerMessage(
        for chainId: ChainModel.Id,
        account: AccountAddress,
        builderClosure: @escaping ExtrinsicBuilderClosure
    ) throws -> Data {
        let payloadWithProof = try performTransactionGeneration(for: chainId, builderClosure: builderClosure)
        return try createSignerMessage(
            for: payloadWithProof,
            account: account,
            chainId: chainId
        )
    }

    private func performTransactionGeneration(
        for chainId: ChainModel.Id,
        builderClosure: @escaping ExtrinsicBuilderClosure
    ) throws -> PayloadWithProof {
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
        
        let extrinsicSigningParamsOperation = ClosureOperation<(ExtrinsicSignatureParams, Data)> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            
            guard let metadataHash = try metadataHashWrapper.targetOperation.extractNoCancellableResultData() else {
                throw CommonError.undefined
            }
            
            let customExtensions = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions()
            
            var builder = ExtrinsicBuilder(
                specVersion: codingFactory.specVersion,
                transactionVersion: codingFactory.txVersion,
                genesisHash: chainId
            )
            .with(runtimeJsonContext: codingFactory.createRuntimeJsonContext())
            .with(metadataHash: metadataHash)
            .with(signaturePayloadFormat: .paritySigner)
            
            for customExtension in customExtensions {
                builder = builder.adding(transactionExtension: customExtension)
            }
            
            let finalBuilder = try builderClosure(builder)
            
            let proofParams = try finalBuilder.buildExtrinsicSignatureParams(
                encodingFactory: codingFactory,
                metadata: codingFactory.metadata
            )
            
            let signingPayload = try finalBuilder.buildSignaturePayload(
                encodingFactory: codingFactory,
                metadata: codingFactory.metadata
            )
            
            Logger.shared.info("Metadata hash: \(metadataHash.toHex())")
        
            return (proofParams, signingPayload)
        }
        
        extrinsicSigningParamsOperation.addDependency(codingFactoryOperation)
        extrinsicSigningParamsOperation.addDependency(metadataHashWrapper.targetOperation)
        
        let proofWrapper = extrinsicProofFactory.createExtrinsicProofWrapper(
            for: chain,
            connection: connection
        ) {
            let (proofParams, _) = try extrinsicSigningParamsOperation.extractNoCancellableResultData()
            
            return proofParams
        }
        
        proofWrapper.addDependency(operations: [extrinsicSigningParamsOperation])
        
        let mappingOperation = ClosureOperation<PayloadWithProof> {
            let proof = try proofWrapper.targetOperation.extractNoCancellableResultData()
            let (_, signingPayload) = try extrinsicSigningParamsOperation.extractNoCancellableResultData()
            
            return PayloadWithProof(signingPayload: signingPayload, proof: proof)
        }
        
        mappingOperation.addDependency(proofWrapper.targetOperation)
        
        let totalWrapper = proofWrapper
            .insertingHead(operations: [extrinsicSigningParamsOperation])
            .insertingHead(operations: metadataHashWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
        
        operationQueue.addOperations(totalWrapper.allOperations, waitUntilFinished: true)
        
        return try totalWrapper.targetOperation.extractNoCancellableResultData()
    }

    private func createSignerMessage(
        for model: PayloadWithProof,
        account: AccountAddress,
        chainId: ChainModel.Id
    ) throws -> Data {
        let messageFactory = ParitySignerMessageOperationFactory()
        let cryptoType = account.isHex() ? MultiassetCryptoType.ethereumEcdsa : .sr25519
        let accountId = try account.toAccountId()
        
        let operationQueue = OperationQueue()
        
        let wrapper = messageFactory.createProofBasedTransaction(
            for: model.signingPayload,
            metadataProofClosure: {
                model.proof
            },
            signingIdentity: .regular(.init(accountId: accountId, cryptoType: cryptoType)),
            genesisHash: chainId
        )
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
