import XCTest
@testable import NovaAppAttest

final class AttestationProfile2Tests: XCTestCase {
    private struct Vector {
        let name: String
        let purpose: AttestationProfile2.Purpose
        let url: String
        let method: String
        let contentType: String
        let bodyDigest: String
        let preimage: String
        let digest: String
    }

    private let challenge = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
    private let clientId = "6f2c1e4a-0000-4000-8000-000000000001"

    private var vectors: [Vector] {
        [
            Vector(
                name: "ios_registration_context",
                purpose: .register,
                url: "https://api.example.test/v1/attestation/register",
                method: "POST",
                contentType: "application/json",
                bodyDigest: "73fc118ba082842ad62d2aa2df5fa8e8c6075b3eb3b191b8bda6524cb43c3b93",
                preimage: "4e4f56412d4154544553544154494f4e000002010000002b41414543417751464267634943516f4c4441304f4478415245684d554652595847426b61477877644868380000002436663263316534612d303030302d343030302d383030302d30303030303030303030303100000004504f5354000000056874747073000000106170692e6578616d706c652e7465737400000003343433000000182f76312f6174746573746174696f6e2f7265676973746572000000106170706c69636174696f6e2f6a736f6e73fc118ba082842ad62d2aa2df5fa8e8c6075b3eb3b191b8bda6524cb43c3b93",
                digest: "390441df44cb759b6d79b6e8bd4d1caacc3085bc41140cd5943e3cdf4e932bb1"
            ),
            Vector(
                name: "protected_json",
                purpose: .request,
                url: "https://api.example.test/v1/bittensor/rewards/search",
                method: "POST",
                contentType: "application/json",
                bodyDigest: "f956f5619420dccf364938a43327d70a3adee8d523098d172322681d38fec6c6",
                preimage: "4e4f56412d4154544553544154494f4e000002020000002b41414543417751464267634943516f4c4441304f4478415245684d554652595847426b61477877644868380000002436663263316534612d303030302d343030302d383030302d30303030303030303030303100000004504f5354000000056874747073000000106170692e6578616d706c652e74657374000000033434330000001c2f76312f62697474656e736f722f726577617264732f736561726368000000106170706c69636174696f6e2f6a736f6ef956f5619420dccf364938a43327d70a3adee8d523098d172322681d38fec6c6",
                digest: "5e607f549c641af7569414c81f5b25986b4f868c95d823d8eb00b3c8fb7303dc"
            ),
            Vector(
                name: "protected_empty",
                purpose: .request,
                url: "https://api.example.test/v1/bittensor/subnets",
                method: "GET",
                contentType: "",
                bodyDigest: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                preimage: "4e4f56412d4154544553544154494f4e000002020000002b41414543417751464267634943516f4c4441304f4478415245684d554652595847426b61477877644868380000002436663263316534612d303030302d343030302d383030302d30303030303030303030303100000003474554000000056874747073000000106170692e6578616d706c652e7465737400000003343433000000152f76312f62697474656e736f722f7375626e65747300000000e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                digest: "f24d577ce7fdb0adf08aad08baef56a0e461910d40d8c984525b666af136e2c1"
            )
        ]
    }

    func testPreimageMatchesGatewayVectors() throws {
        for vector in vectors {
            let target = try AttestationRequestTarget(
                url: XCTUnwrap(URL(string: vector.url)),
                method: vector.method,
                contentType: vector.contentType
            )

            let preimage = AttestationProfile2.preimage(
                purpose: vector.purpose,
                challenge: challenge,
                clientId: clientId,
                target: target,
                bodyDigest: try hex(vector.bodyDigest)
            )

            XCTAssertEqual(preimage.toHexString(), vector.preimage, vector.name)
            XCTAssertEqual(preimage.sha256().toHexString(), vector.digest, vector.name)
        }
    }

    func testRegistrationDigestMatchesGatewayVector() {
        let digest = AttestationProfile2.registrationDigest(
            platform: "ios",
            appId: "ABCDEFGHIJ.com.example.nova",
            attestationType: "app_attest",
            keyReference: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=",
            appAttestEnvironment: "development"
        )

        XCTAssertEqual(
            digest.toHexString(),
            "73fc118ba082842ad62d2aa2df5fa8e8c6075b3eb3b191b8bda6524cb43c3b93"
        )
    }
}

// MARK: - Private

private extension AttestationProfile2Tests {
    func hex(_ value: String) throws -> Data {
        let bytes = stride(from: 0, to: value.count, by: 2).compactMap { offset -> UInt8? in
            let start = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(start, offsetBy: 2)

            return UInt8(value[start ..< end], radix: 16)
        }

        XCTAssertEqual(bytes.count, value.count / 2)

        return Data(bytes)
    }
}

private extension Data {
    func toHexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
