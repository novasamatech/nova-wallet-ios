import UIKit
import SubstrateSdk
import RobinHood
import BigInt
import SoraKeystore

enum DAppOperationConfirmInteractorError: Error {
    case addressMismatch(actual: AccountAddress, expected: AccountAddress)
    case extrinsicBadField(name: String)
    case signedExtensionsMismatch(actual: [String], expected: [String])
    case invalidRawSignature(data: Data)
}

final class DAppOperationConfirmInteractor {
    struct ProcessedResult {
        let account: ChainAccountResponse
        let extrinsic: DAppParsedExtrinsic
    }

    weak var presenter: DAppOperationConfirmInteractorOutputProtocol?

    let request: DAppOperationRequest

    let connection: ChainConnection
    let keychain: KeystoreProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var processedResult: ProcessedResult?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var feeWrapper: CompoundOperationWrapper<RuntimeDispatchInfo>?
    private var signWrapper: CompoundOperationWrapper<Data>?

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

    private func createParsedExtrinsicOperation(
        wallet: MetaAccountModel,
        chain: ChainModel,
        dependingOn extrinsicOperation: BaseOperation<PolkadotExtensionExtrinsic>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<ProcessedResult> {
        ClosureOperation<ProcessedResult> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let extrinsic = try extrinsicOperation.extractNoCancellableResultData()

            guard
                let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let accountAddress = try accountResponse.accountId.toAddress(using: accountResponse.chainFormat)

            guard accountAddress == extrinsic.address else {
                throw DAppOperationConfirmInteractorError.addressMismatch(
                    actual: extrinsic.address,
                    expected: accountAddress
                )
            }

            guard
                let specVersion = BigUInt.fromHexString(extrinsic.specVersion),
                codingFactory.specVersion == specVersion else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "specVersion")
            }

            guard
                let transactionVersion = BigUInt.fromHexString(extrinsic.transactionVersion),
                codingFactory.txVersion == transactionVersion else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "transactionVersion")
            }

            guard let tip = BigUInt.fromHexString(extrinsic.tip) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "tip")
            }

            guard let nonce = BigUInt.fromHexString(extrinsic.nonce) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "nonce")
            }

            guard let blockNumber = BigUInt.fromHexString(extrinsic.blockNumber) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "blockNumber")
            }

            let expectedSignedExtensions = codingFactory.metadata.getSignedExtensions()

            guard expectedSignedExtensions == extrinsic.signedExtensions else {
                throw DAppOperationConfirmInteractorError.signedExtensionsMismatch(
                    actual: extrinsic.signedExtensions,
                    expected: expectedSignedExtensions
                )
            }

            let eraData = try Data(hexString: extrinsic.era)

            let eraDecoder = try ScaleDecoder(data: eraData)
            let era = try Era(scaleDecoder: eraDecoder)

            let methodData = try Data(hexString: extrinsic.method)

            let methodDecoder = try codingFactory.createDecoder(from: methodData)

            let method: DAppParsedCall

            if let callableMethod: RuntimeCall<JSON> = try? methodDecoder.read(
                of: KnownType.call.name,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            ) {
                method = .callable(value: callableMethod)
            } else {
                method = .raw(bytes: methodData)
            }

            let parsedExtrinsic = DAppParsedExtrinsic(
                address: extrinsic.address,
                blockHash: extrinsic.blockHash,
                blockNumber: blockNumber,
                era: era,
                genesisHash: extrinsic.genesisHash,
                method: method,
                nonce: nonce,
                specVersion: UInt32(specVersion),
                tip: tip,
                transactionVersion: UInt32(transactionVersion),
                signedExtensions: expectedSignedExtensions,
                version: extrinsic.version
            )

            return ProcessedResult(account: accountResponse, extrinsic: parsedExtrinsic)
        }
    }

    private func processRequestAndContinueSetup(_ request: DAppOperationRequest) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let extrinsicMappingOperation = ClosureOperation<PolkadotExtensionExtrinsic> {
            try request.operationData.map(to: PolkadotExtensionExtrinsic.self)
        }

        let decodingOperation = createParsedExtrinsicOperation(
            wallet: request.wallet,
            chain: request.chain,
            dependingOn: extrinsicMappingOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        decodingOperation.addDependency(extrinsicMappingOperation)
        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try decodingOperation.extractNoCancellableResultData()
                    self?.completeSetup(for: result)
                } catch {
                    self?.presenter?.didReceive(modelResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations(
            [codingFactoryOperation, extrinsicMappingOperation, decodingOperation],
            waitUntilFinished: false
        )
    }

    private func completeSetup(for result: ProcessedResult) {
        processedResult = result

        let confirmationModel = DAppOperationConfirmModel(
            wallet: request.wallet,
            chain: request.chain,
            dApp: request.dApp
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }

    private func createBaseBuilderOperation(
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

    private func createFeePayloadOperation(
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

    private func createSignatureOperation(
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

extension DAppOperationConfirmInteractor: DAppOperationConfirmInteractorInputProtocol {
    func setup() {
        processRequestAndContinueSetup(request)

        if let priceId = request.chain.utilityAssets().first?.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    func confirm() {
        guard signWrapper == nil, let result = processedResult else {
            return
        }

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: request.wallet.metaId,
            accountResponse: result.account
        )

        let signWrapper = createSignatureOperation(for: result, signer: signer)

        self.signWrapper = signWrapper

        signWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.signWrapper != nil else {
                    return
                }

                self?.signWrapper = nil

                guard let request = self?.request else {
                    return
                }

                do {
                    let signature = try signWrapper.targetOperation.extractNoCancellableResultData()
                    let response = DAppOperationResponse(signature: signature)
                    self?.presenter?.didReceive(responseResult: .success(response), for: request)
                } catch {
                    self?.presenter?.didReceive(responseResult: .failure(error), for: request)
                }
            }
        }

        operationQueue.addOperations(signWrapper.allOperations, waitUntilFinished: false)
    }

    func reject() {
        guard signWrapper == nil else {
            return
        }

        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(responseResult: .success(response), for: request)
    }

    func estimateFee() {
        guard feeWrapper == nil, let result = processedResult else {
            return
        }

        guard let signer = try? DummySigner(cryptoType: result.account.cryptoType) else {
            return
        }

        let builderWrapper = createFeePayloadOperation(
            for: result,
            signer: signer
        )

        let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
            engine: connection,
            method: RPCMethod.paymentInfo
        )

        infoOperation.configurationBlock = {
            do {
                let payload = try builderWrapper.targetOperation.extractNoCancellableResultData()
                let extrinsic = payload.toHex(includePrefix: true)
                infoOperation.parameters = [extrinsic]
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(builderWrapper.targetOperation)

        infoOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.feeWrapper != nil else {
                    return
                }

                self?.feeWrapper = nil

                do {
                    let info = try infoOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(feeResult: .success(info))
                } catch {
                    self?.presenter?.didReceive(feeResult: .failure(error))
                }
            }
        }

        let feeWrapper = CompoundOperationWrapper(
            targetOperation: infoOperation,
            dependencies: builderWrapper.allOperations
        )

        self.feeWrapper = feeWrapper

        operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: false)
    }

    func prepareTxDetails() {
        guard let result = processedResult else {
            presenter?.didReceive(txDetailsResult: .failure(CommonError.undefined))
            return
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let encodingOperation = ClosureOperation<JSON> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try result.extrinsic.toScaleCompatibleJSON(
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )
        }

        encodingOperation.addDependency(codingFactoryOperation)

        encodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let txDetails = try encodingOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(txDetailsResult: .success(txDetails))
                } catch {
                    self?.presenter?.didReceive(txDetailsResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations([codingFactoryOperation, encodingOperation], waitUntilFinished: false)
    }
}

extension DAppOperationConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceive(priceResult: result)
    }
}
