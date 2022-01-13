import UIKit
import SubstrateSdk
import RobinHood
import BigInt
import SoraKeystore

final class DAppOperationConfirmInteractor: DAppOperationBaseInteractor {
    struct ProcessedResult {
        let account: ChainAccountResponse
        let extrinsic: DAppParsedExtrinsic
    }

    let request: DAppOperationRequest

    let connection: ChainConnection
    let keychain: KeystoreProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    var processedResult: ProcessedResult?

    var priceProvider: AnySingleValueProvider<PriceData>?
    var feeWrapper: CompoundOperationWrapper<RuntimeDispatchInfo>?
    var signWrapper: CompoundOperationWrapper<Data>?

    init(
        request: DAppOperationRequest,
        runtimeProvider: RuntimeProviderProtocol,
        connection: ChainConnection,
        keychain: KeystoreProtocol,
        priceProviderFactory: PriceProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.keychain = keychain
        priceLocalSubscriptionFactory = priceProviderFactory
        self.operationQueue = operationQueue
    }

    func processRequestAndContinueSetup(_ request: DAppOperationRequest) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let extrinsicMappingOperation = ClosureOperation<PolkadotExtensionExtrinsic> {
            try request.operationData.map(to: PolkadotExtensionExtrinsic.self)
        }

        let decodingWrapper = createParsedExtrinsicOperation(
            wallet: request.wallet,
            chain: request.chain,
            dependingOn: extrinsicMappingOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        decodingWrapper.addDependency(operations: [extrinsicMappingOperation, codingFactoryOperation])

        decodingWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try decodingWrapper.targetOperation.extractNoCancellableResultData()
                    self?.completeSetup(for: result)
                } catch {
                    self?.presenter?.didReceive(modelResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations(
            [codingFactoryOperation, extrinsicMappingOperation] + decodingWrapper.allOperations,
            waitUntilFinished: false
        )
    }

    func completeSetup(for result: ProcessedResult) {
        processedResult = result

        let confirmationModel = DAppOperationConfirmModel(
            wallet: request.wallet,
            chain: request.chain,
            dApp: request.dApp
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }

    func createBaseBuilderOperation(
        for result: ProcessedResult
    ) -> BaseOperation<ExtrinsicBuilderProtocol> {
        ClosureOperation<ExtrinsicBuilderProtocol> {
            let extrinsic = result.extrinsic

            let address = MultiAddress.accoundId(result.account.accountId)

            var builder: ExtrinsicBuilderProtocol = try ExtrinsicBuilder(
                specVersion: extrinsic.specVersion,
                transactionVersion: extrinsic.transactionVersion,
                genesisHash: extrinsic.genesisHash
            )
            .with(address: address)
            .with(nonce: UInt32(extrinsic.nonce))
            .with(era: extrinsic.era, blockHash: extrinsic.blockHash)

            builder = try result.extrinsic.method.accept(builder: builder)

            if extrinsic.tip > 0 {
                builder = builder.with(tip: extrinsic.tip)
            }

            return builder
        }
    }

    func createFeePayloadOperation(
        for result: ProcessedResult,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Data> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderOperation = createBaseBuilderOperation(for: result)

        let payloadOperation = ClosureOperation<Data> {
            let builder = try builderOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try builder.signing(
                with: { try signer.sign($0).rawData() },
                chainFormat: result.account.chainFormat,
                cryptoType: result.account.cryptoType,
                codingFactory: codingFactory
            )
            .build(encodingBy: codingFactory.createEncoder(), metadata: codingFactory.metadata)
        }

        payloadOperation.addDependency(codingFactoryOperation)
        payloadOperation.addDependency(builderOperation)

        return CompoundOperationWrapper(
            targetOperation: payloadOperation,
            dependencies: [codingFactoryOperation, builderOperation]
        )
    }

    func createSignatureOperation(
        for result: ProcessedResult,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Data> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderOperation = createBaseBuilderOperation(for: result)

        let signatureOperation = ClosureOperation<Data> {
            let builder = try builderOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let rawSignature = try builder.buildRawSignature(
                using: { try signer.sign($0).rawData() },
                encoder: codingFactory.createEncoder(),
                metadata: codingFactory.metadata
            )

            let scaleEncoder = codingFactory.createEncoder()

            switch result.account.cryptoType {
            case .sr25519:
                try scaleEncoder.append(
                    MultiSignature.sr25519(data: rawSignature),
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            case .ed25519:
                try scaleEncoder.append(
                    MultiSignature.ed25519(data: rawSignature),
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            case .substrateEcdsa:
                try scaleEncoder.append(
                    MultiSignature.ecdsa(data: rawSignature),
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            case .ethereumEcdsa:
                guard let signature = EthereumSignature(rawValue: rawSignature) else {
                    throw DAppOperationConfirmInteractorError.invalidRawSignature(data: rawSignature)
                }

                try scaleEncoder.append(
                    signature,
                    ofType: KnownType.signature.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            }

            return try scaleEncoder.encode()
        }

        signatureOperation.addDependency(codingFactoryOperation)
        signatureOperation.addDependency(builderOperation)

        return CompoundOperationWrapper(
            targetOperation: signatureOperation,
            dependencies: [codingFactoryOperation, builderOperation]
        )
    }
}
