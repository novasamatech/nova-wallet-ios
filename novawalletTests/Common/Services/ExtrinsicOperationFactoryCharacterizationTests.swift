import BigInt
import NovaCrypto
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Pins the extrinsics the app's own `ExtrinsicOperationFactory` assembles (era, nonce, default extensions,
/// fee installer, sender, signing) for the paths every transaction takes: build, submit and fee estimation.
/// Golden values were recorded on substrate-sdk-ios 4.5.2.
final class ExtrinsicOperationFactoryCharacterizationTests: XCTestCase {
    private static let eraBlockNumber: BlockNumber = 100

    private let operationQueue = OperationQueue()

    func testBuildExtrinsicForSecretsAccount() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let signer = RecordingSigner()

        let model = try build(with: makeFactory(runtime: runtime), signer: signer)

        XCTAssertEqual(signer.payloads.map { $0.toHex(includePrefix: true) }, ["0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"])
        XCTAssertEqual(model.extrinsic, "0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
        XCTAssertEqual(model.sender.account.accountId, ExtrinsicGolden.senderId)
    }

    func testSigningContextRestoresTheSignedBuilder() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let signer = RecordingSigner()

        _ = try build(with: makeFactory(runtime: runtime), signer: signer)

        guard case let .substrateExtrinsic(context) = signer.contexts.first else {
            return XCTFail("Substrate signing context expected")
        }

        let restored = context.extrinsicMemo.restoreBuilder()

        XCTAssertEqual(context.senderResolution.account.accountId, ExtrinsicGolden.senderId)
        XCTAssertEqual(restored.getNonce(), ExtrinsicGolden.nonce)
        XCTAssertEqual(
            try runtime.signaturePayload(of: restored),
            signer.payloads.first?.toHex(includePrefix: true)
        )
    }

    func testSubmitSendsEachExtrinsicWithIncrementedNonce() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let engine = SubmissionEngineStub()
        let factory = try makeFactory(runtime: runtime, engine: engine)

        let wrapper = factory.submit(
            { builder, index in
                try builder.adding(call: ExtrinsicGolden.transferCall(amount: ExtrinsicGolden.amount + BigUInt(index)))
            },
            signer: RecordingSigner(),
            numberOfExtrinsics: 2
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let results = try wrapper.targetOperation.extractNoCancellableResultData().results

        XCTAssertEqual(try results.map { try $0.result.get().txHash }, [SubmissionEngineStub.txHash, SubmissionEngineStub.txHash])
        XCTAssertEqual(engine.submittedExtrinsics.sorted().joined(separator: ";"), "0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8;0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab550020000403002222222222222222222222222222222222222222222222222222222222222222070110a5d4e8")
    }

    func testVaultAccountSignsParitySignerPayload() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let signer = RecordingSigner()

        _ = try build(with: makeFactory(runtime: runtime, accountType: .polkadotVault), signer: signer)

        XCTAssertEqual(signer.payloads.map { $0.toHex(includePrefix: true) }, ["0xa40403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"])
    }

    func testLedgerAccountSignsNotHashedPayload() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let signer = RecordingSigner()
        let factory = try makeFactory(runtime: runtime, accountType: .genericLedger)

        _ = try build(with: factory, signer: signer) { builder in
            try builder.adding(call: ExtrinsicGolden.remarkCall(size: 300))
        }

        XCTAssertEqual(try XCTUnwrap(signer.payloads.first).count, 380)
    }

    func testEcdsaAccountSignatureTypeIsEncoded() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let signer = RecordingSigner(signature: ExtrinsicGolden.ecdsaSignature)

        let model = try build(with: makeFactory(runtime: runtime, cryptoType: .substrateEcdsa), signer: signer)

        XCTAssertEqual(model.extrinsic, "0x45028400111111111111111111111111111111111111111111111111111111111111111102cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd55001c000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testMetadataHashIsInstalledWhenAvailable() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let signer = RecordingSigner()
        let factory = try makeFactory(runtime: runtime, metadataHash: ExtrinsicGolden.metadataHash)

        let model = try build(with: factory, signer: signer)

        XCTAssertEqual(signer.payloads.map { $0.toHex(includePrefix: true) }, ["0x0503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c0001d601000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"])
        XCTAssertEqual(model.extrinsic, "0x45028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c00010503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testFeeInstallerOverridesDefaultChargeAssetTxPayment() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let signer = RecordingSigner()
        let factory = try makeFactory(runtime: runtime, feeInstaller: UsdtFeeInstaller())

        _ = try build(with: factory, signer: signer)

        XCTAssertEqual(signer.payloads.map { $0.toHex(includePrefix: true) }, ["0x0a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c00010002043205011f0008981e000f000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00"])
    }

    func testFeeEstimationBuildsSameExtrinsicWithDummySignature() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let feeRegistry = FeeRegistryStub()
        let factory = try makeFactory(runtime: runtime, feeRegistry: feeRegistry)
        let submitted = try build(with: factory, signer: RecordingSigner())

        let wrapper = factory.estimateFeeOperation(
            { builder, _ in try builder.adding(call: ExtrinsicGolden.transferCall()) },
            numberOfExtrinsics: 1
        )
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let estimated = try XCTUnwrap(feeRegistry.estimatedExtrinsics.first)
        let expected = try Data(hexString: submitted.extrinsic)

        // only the 64 signature bytes differ: they follow the length, version, address and signature type prefix
        let signatureRange = 37 ..< 101
        XCTAssertEqual(estimated.count, expected.count)
        XCTAssertEqual(estimated.prefix(signatureRange.lowerBound), expected.prefix(signatureRange.lowerBound))
        XCTAssertEqual(estimated.suffix(from: signatureRange.upperBound), expected.suffix(from: signatureRange.upperBound))
        XCTAssertNotEqual(estimated.subdata(in: signatureRange), expected.subdata(in: signatureRange))
    }
}

private extension ExtrinsicOperationFactoryCharacterizationTests {
    func makeFactory(
        runtime: ExtrinsicGoldenRuntime,
        engine: JSONRPCEngine = TestJSONRPCEngine(),
        accountType: MetaAccountModelType = .secrets,
        cryptoType: MultiassetCryptoType = .sr25519,
        metadataHash: Data? = nil,
        feeInstaller: ExtrinsicFeeInstalling = ExtrinsicNativeFeeInstaller(),
        feeRegistry: FeeRegistryStub? = nil
    ) throws -> ExtrinsicOperationFactory {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        let account = ChainAccountResponse(
            metaId: "operation-factory-golden-wallet",
            chainId: chain.chainId,
            accountId: ExtrinsicGolden.senderId,
            publicKey: ExtrinsicGolden.senderId,
            name: "Golden",
            cryptoType: cryptoType,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: accountType
        )

        let registry = feeRegistry ?? FeeRegistryStub()
        registry.feeInstaller = feeInstaller

        return ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: RuntimeCodingServiceStub(factory: runtime.codingFactory),
            customExtensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(),
            engine: engine,
            feeEstimationRegistry: registry,
            metadataHashOperationFactory: MetadataHashStub(metadataHash: metadataHash),
            nonceOperationFactory: PresetNonceOperationFactory(nonce: ExtrinsicGolden.nonce),
            senderResolvingFactory: ExtrinsicSenderResolutionFactoryStub(
                resolver: ExtrinsicCurrentSenderResolver(currentAccount: account)
            ),
            eraOperationFactory: PresetEraOperationFactory(
                parameters: .init(blockNumber: Self.eraBlockNumber, extrinsicEra: ExtrinsicGolden.era)
            ),
            blockHashOperationFactory: BlockHashStub(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func build(
        with factory: ExtrinsicOperationFactory,
        signer: SigningWrapperProtocol,
        closure: @escaping ExtrinsicBuilderClosure = { try $0.adding(call: ExtrinsicGolden.transferCall()) }
    ) throws -> ExtrinsicBuiltModel {
        let wrapper = factory.buildExtrinsic(closure, signer: signer, payingFeeIn: nil)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

private final class RecordingSigner: SigningWrapperProtocol {
    private static let sr25519SignatureLength = 64

    private let lock = NSLock()
    private let signature: Data
    private var storedPayloads: [Data] = []
    private var storedContexts: [ExtrinsicSigningContext] = []

    var payloads: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return storedPayloads
    }

    var contexts: [ExtrinsicSigningContext] {
        lock.lock()
        defer { lock.unlock() }
        return storedContexts
    }

    init(signature: Data = ExtrinsicGolden.sr25519Signature) {
        self.signature = signature
    }

    func sign(_ originalData: Data, context: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        lock.lock()
        storedPayloads.append(originalData)
        storedContexts.append(context)
        lock.unlock()

        // 64 bytes for sr25519, 65 (with the recovery id) for ecdsa
        return signature.count == Self.sr25519SignatureLength ?
            try SNSignature(rawData: signature) : try SECSignature(rawData: signature)
    }
}

private final class SubmissionEngineStub: TestJSONRPCEngine {
    static let txHash = "0x" + String(repeating: "07", count: 32)

    private let lock = NSLock()
    private var stored: [String] = []

    var submittedExtrinsics: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    override func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        guard method == RPCMethod.submitExtrinsic, let extrinsics = params as? [String], let hash = Self.txHash as? T else {
            throw CommonError.dataCorruption
        }

        lock.lock()
        stored.append(contentsOf: extrinsics)
        lock.unlock()

        // JSONRPCOperation holds its lock while issuing the call, so the response must not be synchronous
        DispatchQueue.global().async {
            closure?(.success(hash))
        }

        return 1
    }
}

private final class BlockHashStub: BlockHashOperationFactoryProtocol {
    func createBlockHashOperation(
        connection _: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        ClosureOperation { try numberClosure() == 0 ? ExtrinsicGolden.genesisHash : ExtrinsicGolden.blockHash }
    }

    func createBestBlockHashWrapper(connection _: JSONRPCEngine) -> CompoundOperationWrapper<BlockHashData> {
        .createWithError(CommonError.undefined)
    }
}

private final class MetadataHashStub: MetadataHashOperationFactoryProtocol {
    let metadataHash: Data?

    init(metadataHash: Data?) {
        self.metadataHash = metadataHash
    }

    func createCheckMetadataHashWrapper(
        for _: ChainModel,
        connection _: JSONRPCEngine,
        runtimeProvider _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data?> {
        .createWithResult(metadataHash)
    }
}

/// Pays the fee in USDT the way `ExtrinsicAssetConversionFeeInstaller` does, without needing a full chain asset.
private final class UsdtFeeInstaller: ExtrinsicFeeInstalling {
    func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let usdt = AssetConversionPallet.AssetId(
            parents: 0,
            interior: .init(items: [.palletInstance(50), .generalIndex(1984)])
        )

        return ExtrinsicSignedExtensionFactory().createExtensions(payingFeeIn: usdt).reduce(builder) {
            $0.adding(transactionExtension: $1)
        }
    }
}

private final class FeeRegistryStub: ExtrinsicFeeEstimationRegistring {
    private let lock = NSLock()
    private var stored: [Data] = []

    var feeInstaller: ExtrinsicFeeInstalling = ExtrinsicNativeFeeInstaller()

    var estimatedExtrinsics: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func createFeeEstimatingWrapper(
        payingIn _: ChainAssetId?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        let operation = ClosureOperation<ExtrinsicFeeEstimationResultProtocol> {
            let extrinsics = try extrinsicCreatingResultClosure().extrinsics

            self.lock.lock()
            self.stored.append(contentsOf: extrinsics)
            self.lock.unlock()

            // the fee itself is out of scope here: only the extrinsic handed to the estimator is pinned
            throw CommonError.noDataRetrieved
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createFeeInstallerWrapper(
        payingIn _: ChainAssetId?,
        accountClosure _: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        .createWithResult(feeInstaller)
    }
}
