import BigInt
import Foundation
@testable import novawallet
import SubstrateSdk

/// Deterministic inputs shared by the characterization tests that pin SubstrateSdk-facing behaviour
/// with golden bytes: every value is fixed so an encoding change shows up as a byte diff.
enum ExtrinsicGolden {
    static let senderId = Data(repeating: 0x11, count: 32)
    static let receiverId = Data(repeating: 0x22, count: 32)
    static let thirdPartyId = Data(repeating: 0x33, count: 32)

    static let genesisHash = "0x" + String(repeating: "aa", count: 32)
    static let blockHash = "0x" + String(repeating: "bb", count: 32)
    static let metadataHash = Data(repeating: 0xCC, count: 32)

    static let era = Era.mortal(period: 64, phase: 5)
    static let nonce: UInt32 = 7
    static let amount = BigUInt(1_000_000_000_000)

    static let sr25519Signature = Data(repeating: 0xAB, count: 64)
    static let ecdsaSignature = Data(repeating: 0xCD, count: 65)

    static func transferCall(
        to receiver: AccountId = receiverId,
        amount: BigUInt = amount
    ) -> RuntimeCall<TransferCall> {
        SubstrateCallFactory().nativeTransfer(to: receiver, amount: amount, callPath: .transferKeepAlive)
    }

    static func remarkCall(size: Int) -> RuntimeCall<SystemRemarkCall> {
        SubstrateCallFactory().remark(remark: Data(repeating: 0x5A, count: size))
    }

    /// Canonical JSON text: keys sorted, so the string is stable across runs and SDK versions.
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(value)

        return String(data: data, encoding: .utf8) ?? ""
    }

    static func parseJSON(_ text: String) throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: Data(text.utf8))
    }
}

/// A runtime (metadata fixture + type registry) the golden tests build and decode extrinsics against.
struct ExtrinsicGoldenRuntime {
    struct Signed {
        let extrinsic: String
        let signedPayload: String
    }

    let codingFactory: RuntimeCoderFactoryProtocol

    var metadata: RuntimeMetadataProtocol { codingFactory.metadata }

    static func westend() throws -> ExtrinsicGoldenRuntime {
        try .init(codingFactory: RuntimeCodingServiceStub.createWestendCodingFactory(specVersion: 9260, txVersion: 11))
    }

    static func bittensor() throws -> ExtrinsicGoldenRuntime {
        try .init(codingFactory: RuntimeCodingServiceStub.createBittensorCodingFactory())
    }

    static func polkadotAssetHub() throws -> ExtrinsicGoldenRuntime {
        try .init(codingFactory: RuntimeCodingServiceStub.createPolkadotAssetHubCodingFactory())
    }

    static func avail() throws -> ExtrinsicGoldenRuntime {
        try .init(codingFactory: RuntimeCodingServiceStub.createAvailCodingFactory())
    }

    /// The builder state every production path reaches before calls are added: runtime versions,
    /// genesis, mortal era, nonce and the sender address.
    func makeBuilder(era: Era = ExtrinsicGolden.era) throws -> ExtrinsicBuilderProtocol {
        try ExtrinsicBuilder(
            specVersion: codingFactory.specVersion,
            transactionVersion: codingFactory.txVersion,
            genesisHash: ExtrinsicGolden.genesisHash
        )
        .with(runtimeJsonContext: codingFactory.createRuntimeJsonContext())
        .with(era: era, blockHash: ExtrinsicGolden.blockHash)
        .with(nonce: ExtrinsicGolden.nonce)
        .with(address: MultiAddress.accoundId(ExtrinsicGolden.senderId))
    }

    func signaturePayload(of builder: ExtrinsicBuilderProtocol) throws -> String {
        try builder.buildSignaturePayload(encodingFactory: codingFactory, metadata: metadata).toHex(includePrefix: true)
    }

    func signatureParams(of builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicSignatureParams {
        try builder.buildExtrinsicSignatureParams(encodingFactory: codingFactory, metadata: metadata)
    }

    /// Signs with a fixed fake signature and reports both the built extrinsic and the bytes handed to the signer.
    func sign(
        _ builder: ExtrinsicBuilderProtocol,
        cryptoType: CryptoType = .sr25519,
        signature: Data = ExtrinsicGolden.sr25519Signature
    ) throws -> Signed {
        var signedPayload = Data()

        let extrinsic = try builder.signing(
            by: { payload in
                signedPayload = payload
                return signature
            },
            of: cryptoType,
            using: codingFactory,
            metadata: metadata
        )
        .build(using: codingFactory, metadata: metadata)

        return Signed(
            extrinsic: extrinsic.toHex(includePrefix: true),
            signedPayload: signedPayload.toHex(includePrefix: true)
        )
    }

    func decodeExtrinsic(_ hex: String) throws -> Extrinsic {
        let decoder = try codingFactory.createDecoder(from: Data(hexString: hex))

        // no json context on purpose: this is how ExtrinsicProcessor and the other app decoders read it
        return try decoder.read(of: GenericType.extrinsic.name)
    }

    func encodeCall(_ call: JSON) throws -> String {
        let encoder = codingFactory.createEncoder()
        try encoder.append(json: call, type: GenericType.call.name)

        return try encoder.encode().toHex(includePrefix: true)
    }
}
