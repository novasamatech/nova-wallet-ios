import UIKit
import SubstrateSdk
import RobinHood
import BigInt
import SoraKeystore

final class DAppOperationConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel

    let connection: ChainConnection
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    var processedResult: DAppOperationProcessedResult?

    var priceProvider: AnySingleValueProvider<PriceData>?
    var feeWrapper: CompoundOperationWrapper<RuntimeDispatchInfo>?
    var signWrapper: CompoundOperationWrapper<Data>?

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        runtimeProvider: RuntimeProviderProtocol,
        connection: ChainConnection,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        priceProviderFactory: PriceProviderFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.signingWrapperFactory = signingWrapperFactory
        priceLocalSubscriptionFactory = priceProviderFactory
        self.operationQueue = operationQueue
    }

    func processRequestAndContinueSetup(_ request: DAppOperationRequest, chain: ChainModel) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let extrinsicMappingOperation = ClosureOperation<PolkadotExtensionExtrinsic> {
            try request.operationData.map(to: PolkadotExtensionExtrinsic.self)
        }

        let decodingWrapper = createParsedExtrinsicOperation(
            wallet: request.wallet,
            chain: chain,
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

    func completeSetup(for result: DAppOperationProcessedResult) {
        processedResult = result

        let networkIconUrl: URL?
        let assetPrecision: UInt16

        if let asset = chain.utilityAssets().first {
            networkIconUrl = asset.icon ?? chain.icon
            assetPrecision = asset.precision
        } else {
            networkIconUrl = nil
            assetPrecision = 0
        }

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletAccountId: request.wallet.substrateAccountId,
            chainAccountId: result.account.accountId,
            chainAddress: result.account.toAddress() ?? "",
            networkName: chain.name,
            utilityAssetPrecision: Int16(bitPattern: assetPrecision),
            dApp: request.dApp,
            dAppIcon: request.dAppIcon,
            networkIcon: networkIconUrl
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }

    func createBaseBuilderOperation(
        for result: DAppOperationProcessedResult
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
            .adding(extrinsicExtension: ChargeAssetTxPayment())

            builder = try result.extrinsic.method.accept(builder: builder)

            if extrinsic.tip > 0 {
                builder = builder.with(tip: extrinsic.tip)
            }

            return builder
        }
    }

    func createFeePayloadOperation(
        for result: DAppOperationProcessedResult,
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
        for result: DAppOperationProcessedResult,
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
