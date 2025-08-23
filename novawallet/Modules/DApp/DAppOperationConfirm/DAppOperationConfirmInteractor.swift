import UIKit
import SubstrateSdk
import Operation_iOS
import BigInt
import Keystore_iOS

final class DAppOperationConfirmInteractor: DAppOperationBaseInteractor {
    struct SignatureResult {
        let signature: Data
        let modifiedExtrinsic: Data?
    }

    let request: DAppOperationRequest
    let chain: ChainModel

    let connection: JSONRPCEngine
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let metadataHashFactory: MetadataHashOperationFactoryProtocol
    let feeEstimationRegistry: ExtrinsicFeeEstimationRegistring
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    var extrinsicFactory: DAppExtrinsicBuilderOperationFactory?
    var feeAsset: ChainAsset?

    var priceProvider: StreamableProvider<PriceData>?
    let feeCancellable = CancellableCallStore()
    var signCancellable = CancellableCallStore()

    init(
        request: DAppOperationRequest,
        chain: ChainModel,
        runtimeProvider: RuntimeProviderProtocol,
        feeEstimationRegistry: ExtrinsicFeeEstimationRegistring,
        connection: JSONRPCEngine,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        metadataHashFactory: MetadataHashOperationFactoryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        priceProviderFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.chain = chain
        self.runtimeProvider = runtimeProvider
        self.feeEstimationRegistry = feeEstimationRegistry
        self.connection = connection
        self.signingWrapperFactory = signingWrapperFactory
        self.metadataHashFactory = metadataHashFactory
        self.userStorageFacade = userStorageFacade
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
            chain: chain,
            runtimeProvider: runtimeProvider,
            connection: connection,
            feeRegistry: feeEstimationRegistry,
            metadataHashOperationFactory: metadataHashFactory,
            senderResolvingFactory: ExtrinsicSenderResolutionFactory(
                chainAccount: result.account,
                chain: chain,
                userStorageFacade: userStorageFacade
            )
        )

        feeAsset = result.feeAsset

        let confirmationModel = DAppOperationConfirmModel(
            accountName: request.wallet.name,
            walletIdenticon: request.wallet.walletIdenticonData(),
            chainAccountId: result.account.accountId,
            chainAddress: result.account.toAddress() ?? "",
            feeAsset: feeAsset,
            dApp: request.dApp,
            dAppIcon: request.dAppIcon
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }

    func createSignatureOperation(
        for extrinsicFactory: DAppExtrinsicBuilderOperationFactory,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SignatureResult> {
        let signatureWrapper = extrinsicFactory.createRawSignatureWrapper(
            payingFeeIn: feeAsset?.chainAssetId
        ) { data, context in
            try signer.sign(data, context: context).rawData()
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let signatureOperation = ClosureOperation<SignatureResult> {
            let signatureResult = try signatureWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let scaleEncoder = codingFactory.createEncoder()

            let rawSignature = signatureResult.signature

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

            let signature = try scaleEncoder.encode()

            return SignatureResult(signature: signature, modifiedExtrinsic: signatureResult.modifiedExtrinsic)
        }

        signatureOperation.addDependency(codingFactoryOperation)
        signatureOperation.addDependency(signatureWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: signatureOperation,
            dependencies: [codingFactoryOperation] + signatureWrapper.allOperations
        )
    }
}
