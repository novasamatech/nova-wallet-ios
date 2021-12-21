import UIKit
import SubstrateSdk
import RobinHood
import BigInt
import SoraKeystore

enum DAppOperationConfirmInteractorError: Error {
    case addressMismatch(actual: AccountAddress, expected: AccountAddress)
    case extrinsicBadField(name: String)
    case signedExtensionsMismatch(actual: [String], expected: [String])
}

final class DAppOperationConfirmInteractor {
    struct ProcessedResult {
        let runtimeCall: RuntimeCall<JSON>
        let account: ChainAccountResponse
        let extrinsic: PolkadotExtensionExtrinsic
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

    private func processRequestAndContinueSetup(_ request: DAppOperationRequest) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let decodingOperation = ClosureOperation<ProcessedResult> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let extrinsic = try request.operationData.map(to: PolkadotExtensionExtrinsic.self)

            guard
                let accountResponse = request.wallet.fetch(for: request.chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let accountAddress = try accountResponse.accountId.toAddress(using: accountResponse.chainFormat)

            guard accountAddress == extrinsic.address else {
                throw DAppOperationConfirmInteractorError.addressMismatch(
                    actual: extrinsic.address,
                    expected: accountAddress
                )
            }

            let callData = try Data(hexString: extrinsic.method)

            let runtimeContext = codingFactory.createRuntimeJsonContext()
            let decoder = try codingFactory.createDecoder(from: callData)

            let call: RuntimeCall<JSON> = try decoder.read(
                of: KnownType.call.name,
                with: runtimeContext.toRawContext()
            )

            return ProcessedResult(runtimeCall: call, account: accountResponse, extrinsic: extrinsic)
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let call = try decodingOperation.extractNoCancellableResultData()
                    self?.completeSetup(for: call)
                } catch {
                    self?.presenter?.didReceive(modelResult: .failure(error))
                }
            }
        }

        operationQueue.addOperations([codingFactoryOperation, decodingOperation], waitUntilFinished: false)
    }

    private func completeSetup(for result: ProcessedResult) {
        processedResult = result

        let confirmationModel = DAppOperationConfirmModel(
            wallet: request.wallet,
            chain: request.chain,
            dApp: request.dApp,
            module: result.runtimeCall.moduleName,
            call: result.runtimeCall.callName,
            amount: nil
        )

        presenter?.didReceive(modelResult: .success(confirmationModel))

        estimateFee()
    }

    private func createBaseBuilderOperation(
        for result: ProcessedResult,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<ExtrinsicBuilderProtocol> {
        ClosureOperation<ExtrinsicBuilderProtocol> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let extrinsic = result.extrinsic

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

            let address = MultiAddress.accoundId(result.account.accountId)

            var builder = try ExtrinsicBuilder(
                specVersion: UInt32(specVersion),
                transactionVersion: UInt32(transactionVersion),
                genesisHash: extrinsic.genesisHash
            )
            .with(address: address)
            .with(nonce: UInt32(nonce))
            .with(era: era, blockHash: extrinsic.blockHash)
            .adding(call: result.runtimeCall)

            if tip > 0 {
                builder = builder.with(tip: tip)
            }

            return builder
        }
    }

    private func createPayloadOperation(
        for result: ProcessedResult,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<Data> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let builderOperation = createBaseBuilderOperation(
            for: result,
            dependingOn: codingFactoryOperation
        )

        builderOperation.addDependency(codingFactoryOperation)

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

        payloadOperation.addDependency(builderOperation)

        return CompoundOperationWrapper(
            targetOperation: payloadOperation,
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

    func confirm() {}

    func reject() {
        let response = DAppOperationResponse(signature: nil)
        presenter?.didReceive(response: response)
    }

    func estimateFee() {
        guard feeWrapper == nil, let result = processedResult else {
            return
        }

        guard let signer = try? DummySigner(cryptoType: result.account.cryptoType) else {
            return
        }

        let builderWrapper = createPayloadOperation(
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
}

extension DAppOperationConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceive(priceResult: result)
    }
}
