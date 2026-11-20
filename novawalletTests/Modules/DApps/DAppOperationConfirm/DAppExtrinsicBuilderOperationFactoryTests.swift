import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Pins what the dApp signing path (`signPayload` of the injected signer) hands to the signer and returns
/// to the dApp for a parsed `PolkadotExtensionExtrinsic`. Golden values were recorded on substrate-sdk-ios 4.5.2.
final class DAppExtrinsicBuilderOperationFactoryTests: XCTestCase {
    private let operationQueue = OperationQueue()

    func testOriginalPayloadIsSignedAndNotModified() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let factory = try makeFactory(runtime: runtime, extrinsic: makeExtrinsic(runtime: runtime))

        let result = try performRawSignature(with: factory)

        XCTAssertEqual(result.signedPayload, "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(result.output.signature, ExtrinsicGolden.sr25519Signature)
        XCTAssertNil(result.output.modifiedExtrinsic)
        XCTAssertEqual(result.output.sender.account.accountId, ExtrinsicGolden.senderId)
    }

    func testCallableMethodProducesSamePayloadAsRawMethod() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let callJson = try ExtrinsicGolden.transferCall().toScaleCompatibleJSON(
            with: runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        )
        let callable = try callJson.map(to: RuntimeCall<JSON>.self)

        let rawFactory = try makeFactory(runtime: runtime, extrinsic: makeExtrinsic(runtime: runtime))
        let callableFactory = try makeFactory(
            runtime: runtime,
            extrinsic: makeExtrinsic(runtime: runtime, method: .callable(value: callable))
        )

        XCTAssertEqual(
            try performRawSignature(with: callableFactory).signedPayload,
            try performRawSignature(with: rawFactory).signedPayload
        )
    }

    func testSignedTransactionUsesRemoteNonceAndReturnsModifiedExtrinsic() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let engine = DAppNonceEngineStub(nonce: 42)
        let factory = try makeFactory(
            runtime: runtime,
            extrinsic: makeExtrinsic(runtime: runtime, withSignedTransaction: true),
            engine: engine
        )

        let result = try performRawSignature(with: factory)

        XCTAssertEqual(engine.requestedMethods, [RPCMethod.getExtrinsicNonce])
        XCTAssertEqual(result.signedPayload, "0x0403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e85500a8002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        XCTAssertEqual(result.output.signature, ExtrinsicGolden.sr25519Signature)
        XCTAssertEqual(result.output.modifiedExtrinsic?.toHex(includePrefix: true), "0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab5500a8000403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testSignedTransactionInstallsMetadataHashWhenDAppOmitsIt() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let factory = try makeFactory(
            runtime: runtime,
            extrinsic: makeExtrinsic(runtime: runtime, withSignedTransaction: true),
            metadataHash: ExtrinsicGolden.metadataHash
        )

        let result = try performRawSignature(with: factory)

        XCTAssertEqual(result.signedPayload, "0x0503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e85500000001d601000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
        XCTAssertEqual(result.output.modifiedExtrinsic?.toHex(includePrefix: true), "0x45028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55000000010503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testDeclaredMetadataHashIsUsedWithoutModification() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let declaredHash = Data(repeating: 0xEE, count: 32)
        let factory = try makeFactory(
            runtime: runtime,
            extrinsic: makeExtrinsic(runtime: runtime, metadataHash: declaredHash.toHex(includePrefix: true)),
            metadataHash: ExtrinsicGolden.metadataHash
        )

        let result = try performRawSignature(with: factory)

        XCTAssertEqual(result.signedPayload, "0x0503002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c0001d601000001000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb01eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
        XCTAssertNil(result.output.modifiedExtrinsic)
    }

    /// Pins what happens today, not what a dApp expects: the default `ChargeAssetTxPayment()` the factory adds
    /// after sender resolution replaces the extension built from the dApp's `assetId` and tip, so the signed
    /// payload carries `tip = 0, asset = None`. Kept as is here; a change of these bytes must be deliberate.
    func testAssetIdAndTipAreReplacedByDefaultChargeAssetTxPayment() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let assetId = try ChargeAssetTxSerializer.decodeFeeAssetId(Self.usdtLocationHex, codingFactory: runtime.codingFactory)
        let factory = try makeFactory(
            runtime: runtime,
            extrinsic: makeExtrinsic(runtime: runtime, tip: 3, assetId: assetId)
        )

        let result = try performRawSignature(with: factory)

        XCTAssertEqual(try ExtrinsicGolden.json(assetId), "null")
        XCTAssertEqual(result.signedPayload, "0x0a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c00000008981e000f000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00")
    }

    func testNumericAssetIdIsPassedAsString() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        let assetId = try ChargeAssetTxSerializer.decodeFeeAssetId("1984", codingFactory: runtime.codingFactory)

        XCTAssertEqual(assetId, .stringValue("1984"))
    }

    func testVaultAccountSignsParitySignerPayload() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let factory = try makeFactory(
            runtime: runtime,
            extrinsic: makeExtrinsic(runtime: runtime),
            accountType: .polkadotVault
        )

        let result = try performRawSignature(with: factory)

        XCTAssertEqual(result.signedPayload, "0xa40403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e855001c002c2400000b000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    }

    func testCreateWrapperBuildsSignedExtrinsic() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let factory = try makeFactory(runtime: runtime, extrinsic: makeExtrinsic(runtime: runtime, tip: 5))

        let wrapper = factory.createWrapper(
            customClosure: { builder, _ in builder },
            indexes: [0],
            payingFeeIn: nil,
            signingClosure: { _, _ in ExtrinsicGolden.sr25519Signature }
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()

        XCTAssertEqual(result.extrinsics.map { $0.toHex(includePrefix: true) }, ["0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c140403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8"])
    }
}

private extension DAppExtrinsicBuilderOperationFactoryTests {
    struct RawSignature {
        let output: DAppExtrinsicRawSignatureResult
        let signedPayload: String
    }

    /// SCALE of `Location { parents: 0, interior: X2(PalletInstance(50), GeneralIndex(1984)) }`, as a dApp sends it.
    static let usdtLocationHex = "0x0002043205011f"

    func makeExtrinsic(
        runtime: ExtrinsicGoldenRuntime,
        method: DAppParsedCall? = nil,
        tip: BigUInt = 0,
        metadataHash: String? = nil,
        assetId: JSON? = nil,
        withSignedTransaction: Bool = false
    ) throws -> DAppParsedExtrinsic {
        let callJson = try ExtrinsicGolden.transferCall().toScaleCompatibleJSON(
            with: runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        )
        let rawCall = try Data(hexString: runtime.encodeCall(callJson))

        return DAppParsedExtrinsic(
            address: try ExtrinsicGolden.senderId.toAddress(using: .substrate(42)),
            blockHash: ExtrinsicGolden.blockHash,
            blockNumber: 100,
            era: ExtrinsicGolden.era,
            genesisHash: ExtrinsicGolden.genesisHash,
            method: method ?? .raw(bytes: rawCall),
            nonce: BigUInt(ExtrinsicGolden.nonce),
            specVersion: runtime.codingFactory.specVersion,
            tip: tip,
            transactionVersion: runtime.codingFactory.txVersion,
            metadataHash: metadataHash,
            assetId: assetId,
            withSignedTransaction: withSignedTransaction,
            signedExtensions: runtime.metadata.getSignedExtensions(),
            version: 4
        )
    }

    func makeFactory(
        runtime: ExtrinsicGoldenRuntime,
        extrinsic: DAppParsedExtrinsic,
        engine: JSONRPCEngine = DAppNonceEngineStub(nonce: 0),
        metadataHash: Data? = nil,
        accountType: MetaAccountModelType = .secrets
    ) throws -> DAppExtrinsicBuilderOperationFactory {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        let account = ChainAccountResponse(
            metaId: "dapp-golden-wallet",
            chainId: chain.chainId,
            accountId: ExtrinsicGolden.senderId,
            publicKey: ExtrinsicGolden.senderId,
            name: "Golden",
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: accountType
        )

        return DAppExtrinsicBuilderOperationFactory(
            processedResult: DAppOperationProcessedResult(account: account, extrinsic: extrinsic, feeAsset: nil),
            chain: chain,
            runtimeProvider: RuntimeCodingServiceStub(factory: runtime.codingFactory),
            connection: engine,
            feeRegistry: DAppUnusedFeeRegistry(),
            metadataHashOperationFactory: DAppMetadataHashFactoryStub(metadataHash: metadataHash),
            senderResolvingFactory: ExtrinsicSenderResolutionFactoryStub(
                resolver: ExtrinsicCurrentSenderResolver(currentAccount: account)
            )
        )
    }

    func performRawSignature(with factory: DAppExtrinsicBuilderOperationFactory) throws -> RawSignature {
        var signedPayload = Data()

        let wrapper = factory.createRawSignatureWrapper(payingFeeIn: nil) { payload, _ in
            signedPayload = payload
            return ExtrinsicGolden.sr25519Signature
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return RawSignature(
            output: try wrapper.targetOperation.extractNoCancellableResultData(),
            signedPayload: signedPayload.toHex(includePrefix: true)
        )
    }
}

final class DAppNonceEngineStub: TestJSONRPCEngine {
    let nonce: UInt32
    private(set) var requestedMethods: [String] = []

    init(nonce: UInt32) {
        self.nonce = nonce
    }

    override func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        requestedMethods.append(method)

        let result: Result<T, Error>

        if let typedNonce = nonce as? T {
            result = .success(typedNonce)
        } else {
            result = .failure(CommonError.dataCorruption)
        }

        // JSONRPCOperation holds its lock while issuing the call, so the response must not be synchronous
        DispatchQueue.global().async {
            closure?(result)
        }

        return 1
    }
}

final class DAppMetadataHashFactoryStub: MetadataHashOperationFactoryProtocol {
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

/// The dApp path asks the registry only when the user picked a fee asset, which these tests never do.
final class DAppUnusedFeeRegistry: ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn _: ChainAssetId?,
        extrinsicCreatingResultClosure _: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        .createWithError(CommonError.dataCorruption)
    }

    func createFeeInstallerWrapper(
        payingIn _: ChainAssetId?,
        accountClosure _: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        .createWithError(CommonError.dataCorruption)
    }
}
