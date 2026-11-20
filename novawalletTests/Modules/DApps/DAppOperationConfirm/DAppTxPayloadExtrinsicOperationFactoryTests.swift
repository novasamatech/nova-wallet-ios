import BigInt
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Pins the extrinsic a createTransaction payload turns into: byte for byte against what the wallet's own builder
/// produces for the same values and against bytes assembled here by hand for general (v5) transactions.
final class DAppTxPayloadExtrinsicOperationFactoryTests: XCTestCase {
    private typealias ExtensionId = Extrinsic.TransactionExtensionId

    private let operationQueue = OperationQueue()

    // MARK: Legacy extrinsic

    func testLegacyExtrinsicEqualsTheOneOfExistingBuilder() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let engine = DAppNonceEngineStub(nonce: 42)

        var values = DAppTxPayloadFixture.Values()
        values.tip = 5

        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime, values: values)
        let built = try build(with: makeFactory(runtime: runtime, fixture: fixture, engine: engine))

        let expected = try runtime.sign(
            runtime.makeBuilder().with(tip: 5).adding(call: ExtrinsicGolden.transferCall())
        )

        XCTAssertEqual(built.extrinsic, expected.extrinsic)
        XCTAssertEqual(built.signedPayload, expected.signedPayload)

        // the golden value of DAppExtrinsicBuilderOperationFactoryTests.testCreateWrapperBuildsSignedExtrinsic
        XCTAssertEqual(built.extrinsic, "0x41028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c140403002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")

        // everything came with the payload: the node is not asked for anything
        XCTAssertEqual(engine.requestedMethods, [])
        XCTAssertEqual(built.sender.account.accountId, ExtrinsicGolden.senderId)
    }

    func testSuppliedAssetPaymentReachesExtrinsicUnchanged() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        // tip 3 and the fee asset: the same input the signPayload path replaces with its default extension
        let payment = join(Data([0x0C, 0x01]), try Data(hexString: Self.usdtLocationHex))

        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.assetTxPayment, extra: payment)

        let built = try build(with: makeFactory(runtime: runtime, fixture: fixture))
        let native = try build(
            with: makeFactory(runtime: runtime, fixture: DAppTxPayloadFixture.transfer(runtime: runtime))
        )

        let nativeDefault = try runtime.sign(makeWalletBuilder(for: runtime).adding(call: ExtrinsicGolden.transferCall()))

        XCTAssertEqual(native.extrinsic, nativeDefault.extrinsic)
        XCTAssertEqual(native.signedPayload, nativeDefault.signedPayload)

        // era | nonce | payment | metadata hash mode: only the payment differs from the native one
        let nativeExtra = "55001c000000"
        let suppliedExtra = "55001c" + payment.toHex() + "00"

        XCTAssertTrue(native.extrinsic.contains(nativeExtra))
        XCTAssertEqual(built.extrinsic.dropFirst(6), native.extrinsic.replacingOccurrences(of: nativeExtra, with: suppliedExtra).dropFirst(6))
        XCTAssertEqual(built.signedPayload, native.signedPayload.replacingOccurrences(of: nativeExtra, with: suppliedExtra))
        XCTAssertEqual(built.extrinsic, "0x65028400111111111111111111111111111111111111111111111111111111111111111101abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab55001c0c010002043205011f000a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testSuppliedFeeAssetIsReadTheWayAssetHubConverterExpects() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let payment = join(Data([0x0C, 0x01]), try Data(hexString: Self.usdtLocationHex))

        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.assetTxPayment, extra: payment)

        let resolution = try DAppTxPayloadExtensionResolver().resolve(
            payload: fixture.makePayload(),
            codingFactory: runtime.codingFactory,
            chainFacts: runtime.makeChainFacts()
        )

        let explicit = try XCTUnwrap(resolution.supplied(for: ExtensionId.assetTxPayment)?.explicit?.dictValue)
        let feeAssetField = DAppTxPayloadExtrinsicOperationFactory.Constants.feeAssetIdField

        let assetId = try XCTUnwrap(explicit[feeAssetField]).map(
            to: AssetConversionPallet.AssetId.self,
            with: runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        )

        XCTAssertEqual(
            assetId.wrapped.location,
            XcmUni.RelativeLocation(
                parents: 0,
                interior: .init(items: [.palletInstance(50), .generalIndex(1984)])
            )
        )

        // a generated chain has no Asset Hub fees, so the fee stays in the native token
        let wrapper = try makeFactory(runtime: runtime, fixture: fixture).createProcessingWrapper()

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertNil(try wrapper.targetOperation.extractNoCancellableResultData().feeAsset)
    }

    func testOmittedExtensionsAreFilledByWallet() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let engine = DAppNonceEngineStub(nonce: 42)

        let omittedIds = [
            ExtensionId.nonce,
            ExtensionId.mortality,
            ExtensionId.genesis,
            ExtensionId.specVersion,
            ExtensionId.txVersion,
            ExtensionId.assetTxPayment,
            ExtensionId.checkMetadataHash,
            "CheckWeight"
        ]

        let fixture = try omittedIds.reduce(DAppTxPayloadFixture.transfer(runtime: runtime)) { $0.removing($1) }

        let built = try build(
            with: makeFactory(
                runtime: runtime,
                fixture: fixture,
                engine: engine,
                metadataHash: ExtrinsicGolden.metadataHash
            )
        )

        let expected = try runtime.sign(
            makeWalletBuilder(for: runtime)
                .with(nonce: 42)
                .with(metadataHash: ExtrinsicGolden.metadataHash)
                .adding(call: ExtrinsicGolden.transferCall())
        )

        XCTAssertEqual(built.extrinsic, expected.extrinsic)
        XCTAssertEqual(built.signedPayload, expected.signedPayload)
        XCTAssertEqual(engine.requestedMethods, [RPCMethod.getExtrinsicNonce])
    }

    func testSuppliedMetadataHashModeIsKeptForSecretsAndForcedForLedger() throws {
        let runtime = try ExtrinsicGoldenRuntime.bittensor()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        let disabled = try runtime.sign(runtime.makeBuilder().adding(call: ExtrinsicGolden.transferCall()))

        let enabledBuilder = try runtime.makeBuilder()
            .with(metadataHash: ExtrinsicGolden.metadataHash)
            .with(signaturePayloadFormat: .extrinsicPayload)
            .adding(call: ExtrinsicGolden.transferCall())

        let enabled = try runtime.sign(enabledBuilder)

        for accountType in [MetaAccountModelType.secrets, .polkadotVault] {
            let built = try build(
                with: makeFactory(
                    runtime: runtime,
                    fixture: fixture,
                    metadataHash: ExtrinsicGolden.metadataHash,
                    accountType: accountType
                )
            )

            XCTAssertEqual(built.extrinsic, disabled.extrinsic, "\(accountType)")
        }

        for accountType in [MetaAccountModelType.ledger, .genericLedger] {
            let built = try build(
                with: makeFactory(
                    runtime: runtime,
                    fixture: fixture,
                    metadataHash: ExtrinsicGolden.metadataHash,
                    accountType: accountType
                )
            )

            XCTAssertEqual(built.extrinsic, enabled.extrinsic, "\(accountType)")
            XCTAssertEqual(built.signedPayload, enabled.signedPayload, "\(accountType)")
        }

        // nothing to force when the wallet has no hash for the chain
        let withoutHash = try build(
            with: makeFactory(runtime: runtime, fixture: fixture, metadataHash: nil, accountType: .genericLedger)
        )

        XCTAssertEqual(withoutHash.extrinsic, disabled.extrinsic)
    }

    func testVaultAccountSignsParitySignerPayload() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        let built = try build(with: makeFactory(runtime: runtime, fixture: fixture, accountType: .polkadotVault))

        let expected = try runtime.sign(
            runtime.makeBuilder()
                .with(signaturePayloadFormat: .paritySigner)
                .adding(call: ExtrinsicGolden.transferCall())
        )

        XCTAssertEqual(built.signedPayload, expected.signedPayload)
        XCTAssertEqual(built.extrinsic, expected.extrinsic)
    }

    // MARK: Delegated wallets

    func testDelegatedWalletsSignWrappedCallWithNonceOfActualSigner() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let context = runtime.codingFactory.createRuntimeJsonContext().toRawContext()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        let wrappers: [(String, (JSON) throws -> JSON)] = [
            ("proxy", { call in
                try Proxy.ProxyCall(
                    real: .accoundId(ExtrinsicGolden.senderId),
                    forceProxyType: .any,
                    call: call
                ).runtimeCall().toScaleCompatibleJSON(with: context)
            }),
            ("multisig", { call in
                try MultisigPallet.AsMultiThreshold1Call(
                    otherSignatories: [BytesCodable(wrappedValue: ExtrinsicGolden.receiverId)],
                    call: call
                ).runtimeCall().toScaleCompatibleJSON(with: context)
            })
        ]

        for (name, wrapper) in wrappers {
            let engine = DAppNonceEngineStub(nonce: 42)
            let chain = try ExtrinsicGoldenRuntime.makeChain()

            let factory = try makeFactory(
                runtime: runtime,
                fixture: fixture,
                engine: engine,
                chain: chain,
                senderResolver: DAppDelegateSenderResolverStub(
                    delegatedAccount: makeAccount(for: chain, accountId: ExtrinsicGolden.senderId, type: .proxied),
                    delegateAccount: makeAccount(for: chain, accountId: ExtrinsicGolden.thirdPartyId, type: .secrets),
                    chain: chain,
                    wrapper: wrapper
                )
            )

            let built = try build(with: factory)

            // the payload carries nonce 7 of the delegated account: the delegate signs with its own one
            let expectedBuilder = try makeWalletBuilder(for: runtime)
                .with(nonce: 42)
                .with(address: MultiAddress.accoundId(ExtrinsicGolden.thirdPartyId))
                .adding(call: ExtrinsicGolden.transferCall())
                .wrappingCalls(for: wrapper)

            let expected = try runtime.sign(expectedBuilder)

            XCTAssertEqual(built.extrinsic, expected.extrinsic, name)
            XCTAssertEqual(built.signedPayload, expected.signedPayload, name)
            XCTAssertEqual(engine.requestedMethods, [RPCMethod.getExtrinsicNonce], name)
            XCTAssertEqual(built.sender.account.accountId, ExtrinsicGolden.thirdPartyId, name)
        }
    }

    // MARK: General transaction

    func testGeneralTransactionIsSignedThroughVerifyMultiSignature() throws {
        let allIds = try ExtrinsicGoldenRuntime.westendV16ExtensionIds()
        let secondSet = allIds.filter { $0 != "CheckWeight" }

        let runtime = try ExtrinsicGoldenRuntime.westendV16(
            customization: .init(formats: [4, 5], extensionSets: [0: allIds, 1: secondSet])
        )

        var fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
        fixture.txExtVersion = 1

        let built = try build(with: makeFactory(runtime: runtime, fixture: fixture))
        let expected = try assembleGeneralTransaction(for: fixture, pipeline: secondSet, extensionVersion: 1)

        XCTAssertEqual(built.signedPayload, expected.signedPayload)
        XCTAssertEqual(built.extrinsic, expected.extrinsic)
        XCTAssertFalse(expected.explicits.isEmpty)
        XCTAssertFalse(expected.implicits.isEmpty)

        guard case let .generalTransaction(general) = try runtime.decodeExtrinsic(built.extrinsic) else {
            XCTFail("General transaction expected")
            return
        }

        XCTAssertEqual(general.extensionVersion, 1)
        XCTAssertEqual(try runtime.encodeCall(general.call), fixture.callData)
    }

    func testExtensionKnownOnlyToMetadataReachesExtrinsicUnchanged() throws {
        let optionalId = DAppTxPayloadCustomExtension.optionalId

        // general transaction: the whole extrinsic and what is signed are assembled by hand
        let generalRuntime = try ExtrinsicGoldenRuntime.westendV16WithCustomExtensions(formats: [5])
        let fixture = try DAppTxPayloadFixture.customTransfer(runtime: generalRuntime).removing(optionalId)
        let pipeline = try generalRuntime.metadata.getSignedExtensions(forExtensionVersion: 0)

        let general = try build(with: makeFactory(runtime: generalRuntime, fixture: fixture))

        // the optional extension is left out by the dApp: the runtime reads None for it
        let expected = try assembleGeneralTransaction(
            for: fixture,
            pipeline: pipeline,
            extensionVersion: 0,
            emptyOptionalIds: [optionalId]
        )

        XCTAssertEqual(general.signedPayload, expected.signedPayload)
        XCTAssertEqual(general.extrinsic, expected.extrinsic)
        XCTAssertTrue(general.extrinsic.contains(DAppTxPayloadCustomExtension.valueExplicit.toHex()))

        // legacy extrinsic of the same runtime: VerifyMultiSignature is disabled, the signature goes in front
        let legacyRuntime = try ExtrinsicGoldenRuntime.westendV16WithCustomExtensions(formats: [4, 5])
        let legacy = try build(with: makeFactory(runtime: legacyRuntime, fixture: fixture))

        let callData = try Data(hexString: fixture.callData)
        let disabledSignature = Data([0x01])
        let legacyPayload = join(callData, disabledSignature, expected.explicits, expected.implicits)
        let legacySignedPayload = try legacyPayload.count > 256 ? legacyPayload.blake2b32() : legacyPayload

        XCTAssertEqual(legacy.signedPayload, legacySignedPayload.toHex(includePrefix: true))
        XCTAssertTrue(legacy.extrinsic.hasSuffix(join(disabledSignature, expected.explicits, callData).toHex()))
        XCTAssertTrue(legacy.signedPayload != general.signedPayload)
    }

    func testGeneralTransactionOfBaseExtensionVersion() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime).removing(ExtensionId.nonce)

        let built = try build(
            with: makeFactory(runtime: runtime, fixture: fixture, engine: DAppNonceEngineStub(nonce: 42))
        )

        guard case let .generalTransaction(general) = try runtime.decodeExtrinsic(built.extrinsic) else {
            XCTFail("General transaction expected")
            return
        }

        XCTAssertEqual(general.extensionVersion, 0)
        XCTAssertEqual(general.explicits.getNonce(), 42)
        XCTAssertEqual(try Data(hexString: built.signedPayload).count, 32)
    }

    func testGeneralTransactionIsRefusedBySignersThatNeedWholePayload() throws {
        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        for accountType in [MetaAccountModelType.paritySigner, .polkadotVault, .ledger, .genericLedger] {
            let factory = try makeFactory(runtime: runtime, fixture: fixture, accountType: accountType)

            XCTAssertThrowsError(try build(with: factory), "\(accountType)") { error in
                XCTAssertEqual((error as? DAppCreateTransactionError)?.name, "SignerUnavailable")
            }
        }
    }

    // MARK: Verification

    func testVerificationFailureStopsBeforeSigning() throws {
        let runtime = try ExtrinsicGoldenRuntime.westend()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.nonce, extra: Data([0x1C, 0x00]))

        let factory = try makeFactory(runtime: runtime, fixture: fixture)

        var isSignerCalled = false

        let wrapper = factory.createWrapper(
            customClosure: { builder, _ in builder },
            indexes: [0],
            payingFeeIn: nil,
            signingClosure: { _, _ in
                isSignerCalled = true
                return ExtrinsicGolden.sr25519Signature
            }
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            XCTAssertEqual((error as? DAppCreateTransactionError)?.name, "DecodeError")
        }

        XCTAssertFalse(isSignerCalled)
    }

    func testProcessingReportsResolutionAndNativeFee() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)

        let wrapper = try makeFactory(runtime: runtime, fixture: fixture).createProcessingWrapper()

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let result = try wrapper.targetOperation.extractNoCancellableResultData()

        XCTAssertEqual(result.resolution.extrinsicVersion, .V4)
        XCTAssertEqual(result.resolution.call.callName, "transfer_keep_alive")
        XCTAssertNil(result.feeAsset)
    }
}

private extension DAppTxPayloadExtrinsicOperationFactoryTests {
    struct Built {
        let extrinsic: String
        let signedPayload: String
        let sender: ExtrinsicSenderResolution
    }

    /// SCALE of `Location { parents: 0, interior: X2(PalletInstance(50), GeneralIndex(1984)) }`
    static let usdtLocationHex = "0x0002043205011f"

    /// The builder of `ExtrinsicGoldenRuntime` with the extensions the app adds to every extrinsic of its own.
    func makeWalletBuilder(for runtime: ExtrinsicGoldenRuntime) throws -> ExtrinsicBuilderProtocol {
        try ExtrinsicSignedExtensionFactory().createExtensions().reduce(runtime.makeBuilder()) { builder, walletExtension in
            builder.adding(transactionExtension: walletExtension)
        }
    }

    func join(_ parts: Data...) -> Data {
        join(parts)
    }

    func join(_ parts: [Data]) -> Data {
        parts.reduce(into: Data()) { $0.append($1) }
    }

    struct GeneralTransaction {
        let extrinsic: String
        let signedPayload: String
        let explicits: Data
        let implicits: Data
    }

    /// What a runtime expects from a general transaction signed through `VerifyMultiSignature`, assembled from
    /// the bytes of the payload alone: the signature covers blake2-256 of
    /// extension version | call | explicit parts of the following extensions | their implicit parts.
    func assembleGeneralTransaction(
        for fixture: DAppTxPayloadFixture,
        pipeline: [String],
        extensionVersion: UInt8,
        emptyOptionalIds: Set<String> = []
    ) throws -> GeneralTransaction {
        XCTAssertEqual(pipeline.first, ExtensionId.verifySignature)

        var explicits = Data()
        var implicits = Data()

        for identifier in pipeline.dropFirst() {
            guard !emptyOptionalIds.contains(identifier) else {
                explicits.append(0)
                continue
            }

            let supplied = try XCTUnwrap(fixture.extensions.first { $0.id == identifier }, identifier)

            explicits.append(try Data(hexString: supplied.extra))
            implicits.append(try Data(hexString: supplied.additionalSigned))
        }

        let callData = try Data(hexString: fixture.callData)
        let signedPayload = try join(Data([extensionVersion]), callData, explicits, implicits).blake2b32()

        // general transaction of format 5 | extension version | Signed { Sr25519 signature, account } | ...
        let body = join(
            Data([0x45, extensionVersion]),
            Data([0x00, 0x01]),
            ExtrinsicGolden.sr25519Signature,
            ExtrinsicGolden.senderId,
            explicits,
            callData
        )

        let extrinsic = join(try DAppTxPayloadFixture.scale(BigUInt(body.count)), body)

        return GeneralTransaction(
            extrinsic: extrinsic.toHex(includePrefix: true),
            signedPayload: signedPayload.toHex(includePrefix: true),
            explicits: explicits,
            implicits: implicits
        )
    }

    func makeAccount(
        for chain: ChainModel,
        accountId: AccountId = ExtrinsicGolden.senderId,
        type: MetaAccountModelType = .secrets
    ) -> ChainAccountResponse {
        ChainAccountResponse(
            metaId: "dapp-golden-wallet",
            chainId: chain.chainId,
            accountId: accountId,
            publicKey: accountId,
            name: "Golden",
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: type
        )
    }

    func makeFactory(
        runtime: ExtrinsicGoldenRuntime,
        fixture: DAppTxPayloadFixture,
        engine: JSONRPCEngine = DAppNonceEngineStub(nonce: 0),
        metadataHash: Data? = nil,
        accountType: MetaAccountModelType = .secrets,
        chain: ChainModel? = nil,
        senderResolver: ExtrinsicSenderResolving? = nil
    ) throws -> DAppTxPayloadExtrinsicOperationFactory {
        let chain = try chain ?? ExtrinsicGoldenRuntime.makeChain()
        let account = makeAccount(for: chain, type: accountType)

        return DAppTxPayloadExtrinsicOperationFactory(
            payload: fixture.makePayload(),
            chain: chain,
            runtimeProvider: RuntimeCodingServiceStub(factory: runtime.codingFactory),
            connection: engine,
            resolver: DAppTxPayloadExtensionResolver(),
            metadataHashOperationFactory: DAppMetadataHashFactoryStub(metadataHash: metadataHash),
            senderResolvingFactory: ExtrinsicSenderResolutionFactoryStub(
                resolver: senderResolver ?? ExtrinsicCurrentSenderResolver(currentAccount: account)
            ),
            nonceOperationFactory: TransactionNonceOperationFactory(),
            eraOperationFactory: PresetEraOperationFactory(
                parameters: ExtrinsicEraParameters(blockNumber: 100, extrinsicEra: ExtrinsicGolden.era)
            ),
            blockHashOperationFactory: DAppBlockHashFactoryStub(),
            signedExtensionFactory: ExtrinsicSignedExtensionFactory(),
            operationQueue: operationQueue
        )
    }

    func build(with factory: DAppTxPayloadExtrinsicOperationFactory) throws -> Built {
        var signedPayload = Data()

        let wrapper = factory.createWrapper(
            customClosure: { builder, _ in builder },
            indexes: [0],
            payingFeeIn: nil,
            signingClosure: { payload, _ in
                signedPayload = payload
                return ExtrinsicGolden.sr25519Signature
            }
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        let extrinsic = try XCTUnwrap(result.extrinsics.first)

        return Built(
            extrinsic: extrinsic.toHex(includePrefix: true),
            signedPayload: signedPayload.toHex(includePrefix: true),
            sender: result.sender
        )
    }
}

/// Resolves the sender the way the app does for a proxied or a multisig wallet: the call gets wrapped
/// and another account signs it.
private final class DAppDelegateSenderResolverStub: ExtrinsicSenderResolving {
    let delegatedAccount: ChainAccountResponse
    let delegateAccount: ChainAccountResponse
    let chain: ChainModel
    let wrapper: (JSON) throws -> JSON

    init(
        delegatedAccount: ChainAccountResponse,
        delegateAccount: ChainAccountResponse,
        chain: ChainModel,
        wrapper: @escaping (JSON) throws -> JSON
    ) {
        self.delegatedAccount = delegatedAccount
        self.delegateAccount = delegateAccount
        self.chain = chain
        self.wrapper = wrapper
    }

    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        let resolvedDelegate = ExtrinsicSenderResolution.ResolvedDelegate(
            delegateAccount: MetaChainAccountResponse(
                metaId: delegateAccount.metaId,
                substrateAccountId: delegateAccount.accountId,
                ethereumAccountId: nil,
                walletIdenticonData: nil,
                delegationId: nil,
                chainAccount: delegateAccount
            ),
            delegatedAccount: delegatedAccount,
            paths: [:],
            allWallets: [],
            chain: chain,
            failures: []
        )

        return (.delegate(resolvedDelegate), try builders.map { try $0.wrappingCalls(for: wrapper) })
    }
}
