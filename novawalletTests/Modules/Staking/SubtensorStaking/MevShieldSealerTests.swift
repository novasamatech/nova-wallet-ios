import Cuckoo
@testable import novawallet
import SubstrateSdk
import XCTest

final class MevShieldSealerTests: XCTestCase {
    func testSealMatchesSdkVectorForSignedExtrinsicSizedPlaintext() throws {
        try assertSealMatchesSdkVector(caseName: "signed_extrinsic_sized_150")
    }

    func testSealMatchesSdkVectorForOneBytePlaintext() throws {
        try assertSealMatchesSdkVector(caseName: "one_byte")
    }
}

private extension MevShieldSealerTests {
    func assertSealMatchesSdkVector(caseName: String) throws {
        let vector = try MevShieldSealVector.load()
        let sample = try XCTUnwrap(vector.cases.first { $0.name == caseName })
        let kemRandomness = try Data(hexString: sample.m)
        let nonce = try Data(hexString: sample.nonce)
        let randomness = MockMevShieldRandomnessSourceProtocol()
        stub(randomness) { stub in
            when(stub.randomBytes(count: any())).thenReturn(kemRandomness, nonce)
        }

        let payload = try MevShieldSealer(randomness: randomness).seal(
            plaintext: Data(hexString: sample.plaintext),
            publicKey: Data(hexString: vector.ek)
        )

        let kemCiphertextOffset = MevShieldPallet.keyHashLength + MevShieldPallet.kemCiphertextLengthPrefixLength

        XCTAssertEqual(payload, try Data(hexString: sample.payload))
        XCTAssertEqual(payload.prefix(MevShieldPallet.keyHashLength), try Data(hexString: vector.keyHash))
        XCTAssertEqual(
            payload.dropFirst(kemCiphertextOffset).prefix(MevShieldPallet.kemCiphertextLength),
            try Data(hexString: sample.kemCt)
        )
        let drawSizes = ArgumentCaptor<Int>()
        verify(randomness, times(2)).randomBytes(count: drawSizes.capture())
        XCTAssertEqual(drawSizes.allValues, [kemRandomness.count, nonce.count])
    }
}

private struct MevShieldSealVector: Decodable {
    struct Sample: Decodable {
        let name: String
        let plaintext: String
        let m: String
        let nonce: String
        let kemCt: String
        let payload: String
    }

    let ek: String
    let keyHash: String
    let cases: [Sample]

    static func load() throws -> MevShieldSealVector {
        let url = try XCTUnwrap(
            Bundle(for: MevShieldSealerTests.self).url(forResource: "mev-shield-vector", withExtension: "json")
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(MevShieldSealVector.self, from: Data(contentsOf: url))
    }
}
