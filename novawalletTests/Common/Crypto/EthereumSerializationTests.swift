import BigInt
@testable import novawallet
import NovaCrypto
import SubstrateSdk
import XCTest

final class EthereumSerializationTests: XCTestCase {
    func testSignedEip1559NativeTransferMatchesVector() throws {
        try assertSignedEip1559MatchesVector(named: "eip1559NativeTransfer")
    }

    func testSignedEip1559Erc20TransferMatchesVector() throws {
        try assertSignedEip1559MatchesVector(named: "eip1559Erc20Transfer")
    }

    func testUnsignedEip1559MatchesVector() throws {
        let vector = try TransactionVector.load(named: "eip1559Unsigned")

        let encoded = try vector.serialize(signature: nil)

        XCTAssertEqual(encoded.toHex(), vector.raw)
    }

    func testLegacyWithExternalSignatureMatchesVector() throws {
        let vector = try TransactionVector.load(named: "legacyExternalSignature")
        let signature = try XCTUnwrap(EthereumSignature(rawValue: Data(hexString: XCTUnwrap(vector.signature))))

        let preimage = try vector.serialize(signature: nil)
        let raw = try vector.serialize(signature: signature)

        XCTAssertEqual(try preimage.keccak256().toHex(), vector.preHash)
        XCTAssertEqual(raw.toHex(), vector.raw)
    }

    func testPriorityFeeAboveMaxFeeIsRejected() throws {
        let vector = try TransactionVector.load(named: "eip1559Unsigned")
        let fees = EvmEip1559Fees(maxFeePerGas: 1, maxPriorityFeePerGas: 2)

        XCTAssertThrowsError(
            try EthereumSerializationFactory().serialize(
                transaction: vector.transaction(),
                chainId: vector.chainIdHex(),
                signature: nil,
                eip1559Fees: fees
            )
        )
    }

    func testEip1559SignatureWithRecoveryIdOffsetBy27EncodesAsYParity() throws {
        let vector = try TransactionVector.load(named: "eip1559NativeTransfer")
        let signature = try sign(vector)

        XCTAssertEqual(
            try vector.serialize(signature: signature.replacingRecoveryId(with: 27)),
            try vector.serialize(signature: signature.replacingRecoveryId(with: 0))
        )
        XCTAssertEqual(
            try vector.serialize(signature: signature.replacingRecoveryId(with: 28)),
            try vector.serialize(signature: signature.replacingRecoveryId(with: 1))
        )
    }
}

private extension EthereumSerializationTests {
    func assertSignedEip1559MatchesVector(named name: String) throws {
        let vector = try TransactionVector.load(named: name)

        let preimage = try vector.serialize(signature: nil)
        let raw = try vector.serialize(signature: sign(vector))

        XCTAssertEqual(try preimage.keccak256().toHex(), vector.preHash)
        XCTAssertEqual(raw.toHex(), vector.raw)
    }

    func sign(_ vector: TransactionVector) throws -> EthereumSignature {
        let privateKey = try SECPrivateKey(rawData: Data(hexString: XCTUnwrap(vector.privateKey)))
        let preimage = try vector.serialize(signature: nil)
        let rawSignature = try SECSigner(privateKey: privateKey).sign(preimage.keccak256()).rawData()

        return try XCTUnwrap(EthereumSignature(rawValue: rawSignature))
    }
}

private extension EthereumSignature {
    func replacingRecoveryId(with recoveryId: UInt8) -> EthereumSignature {
        EthereumSignature(rPart: rPart, sPart: sPart, vPart: recoveryId)
    }
}

private struct TransactionVector: Decodable {
    let source: String
    let privateKey: String?
    let signature: String?
    let chainId: String
    let nonce: String
    let gasLimit: String
    let gasPrice: String?
    let maxFeePerGas: String?
    let maxPriorityFeePerGas: String?
    let to: String
    let value: String
    let data: String
    let preHash: String?
    let raw: String

    static func load(named name: String) throws -> TransactionVector {
        let url = try XCTUnwrap(
            Bundle(for: EthereumSerializationTests.self).url(forResource: "transaction-vectors", withExtension: "json")
        )

        let vectors = try JSONDecoder().decode([String: TransactionVector].self, from: Data(contentsOf: url))

        return try XCTUnwrap(vectors[name])
    }

    func chainIdHex() throws -> String {
        try Self.hex(chainId)
    }

    func transaction() throws -> EthereumTransaction {
        EthereumTransaction(
            from: "",
            to: to,
            gas: try Self.hex(gasLimit),
            gasPrice: try gasPrice.map(Self.hex),
            value: try Self.hex(value),
            data: data.isEmpty ? nil : "0x" + data,
            nonce: try Self.hex(nonce)
        )
    }

    func eip1559Fees() throws -> EvmEip1559Fees? {
        guard let maxFeePerGas, let maxPriorityFeePerGas else {
            return nil
        }

        return EvmEip1559Fees(
            maxFeePerGas: try XCTUnwrap(BigUInt(maxFeePerGas, radix: 10)),
            maxPriorityFeePerGas: try XCTUnwrap(BigUInt(maxPriorityFeePerGas, radix: 10))
        )
    }

    func serialize(signature: EthereumSignature?) throws -> Data {
        try EthereumSerializationFactory().serialize(
            transaction: transaction(),
            chainId: chainIdHex(),
            signature: signature,
            eip1559Fees: eip1559Fees()
        )
    }

    private static func hex(_ decimal: String) throws -> String {
        try XCTUnwrap(BigUInt(decimal, radix: 10)).toHexString()
    }
}
