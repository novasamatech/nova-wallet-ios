import UIKit
import SubstrateSdk
import RobinHood
import BigInt
import SoraKeystore

final class DAppOperationConfirmInteractor: DAppOperationBaseInteractor {
    let request: DAppOperationRequest
    let chain: ChainModel

    let connection: JSONRPCEngine
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    var extrinsicFactory: DAppExtrinsicBuilderOperationFactory?

    var priceProvider: StreamableProvider<PriceData>?
    var feeWrapper: CompoundOperationWrapper<RuntimeDispatchInfo>?
    var signWrapper: CompoundOperationWrapper<Data>?

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        priceProviderFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.signingWrapperFactory = signingWrapperFactory
        priceLocalSubscriptionFactory = priceProviderFactory
        self.operationQueue = operationQueue
        super.init()

        self.currencyManager = currencyManager
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
        extrinsicFactory = DAppExtrinsicBuilderOperationFactory(
            processedResult: result,
            runtimeProvider: runtimeProvider
        )

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: result.account.accountId,
            chainAddress: result.account.toAddress() ?? "",
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }

    func createSignatureOperation(
        for extrinsicFactory: DAppExtrinsicBuilderOperationFactory,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Data> {
        let signatureWrapper = extrinsicFactory.createWrapper(
            customClosure: { builder, _ in builder },
            indexes: [0],
            signingClosure: { data in
                try signer.sign(data).rawData()
            }
        )

        let codingFactoryOperation = extrinsicFactory.runtimeProvider.fetchCoderFactoryOperation()

        let signatureOperation = ClosureOperation<Data> {
            let rawSignatures = try signatureWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard let rawSignature = rawSignatures.first else {
                throw CommonError.dataCorruption
            }

            let scaleEncoder = codingFactory.createEncoder()

            switch extrinsicFactory.processedResult.account.cryptoType {
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
        signatureOperation.addDependency(signatureWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: signatureOperation,
            dependencies: [codingFactoryOperation] + signatureWrapper.allOperations
        )
    }
}
