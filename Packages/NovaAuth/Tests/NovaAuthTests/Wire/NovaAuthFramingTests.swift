import XCTest
import CryptoKit
@testable import NovaAuth

final class NovaAuthFramingTests: XCTestCase {
    func testPinnedIOSVectorsReproduceCompletePreimagesAndAppleInput() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "profile-3-ios-vectors", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.vectors.count, 2)
        for vector in fixture.vectors {
            let origin = try NovaAuthOrigin("https://" + vector.context.authority)
            let purpose: NovaAuthPurpose = vector.name == "ios_registration" ? .registration : .token
            let body: Data
            if let binding = vector.binding {
                let identity = try NovaAuthAppIdentity(appID: binding.app_id, environment: .production)
                body = try NovaAuthFraming.registrationPreimage(appIdentity: identity, keyID: binding.key_reference)
                XCTAssertEqual(hex(body), vector.registration_preimage_hex)
            } else {
                body = try NovaAuthFraming.issuancePreimage(origin: origin)
                XCTAssertEqual(hex(body), vector.issuance_preimage_hex)
            }
            let digest = Data(SHA256.hash(data: body))
            XCTAssertEqual(hex(digest), vector.body_sha256)
            let preimage = try NovaAuthFraming.preimage(
                challenge: vector.context.challenge,
                clientID: vector.context.client_id,
                origin: origin,
                purpose: purpose,
                contentType: vector.context.content_type,
                bodyDigest: digest
            )
            XCTAssertEqual(hex(preimage), vector.preimage_hex)
            let clientDataHash = try NovaAuthFraming.clientDataHash(
                challenge: vector.context.challenge,
                clientID: vector.context.client_id,
                origin: origin,
                purpose: purpose,
                contentType: vector.context.content_type,
                bodyDigest: digest
            )
            XCTAssertEqual(hex(clientDataHash), vector.context_sha256)
            XCTAssertEqual(clientDataHash.base64EncodedString(), vector.client_data_hash_base64)
        }
    }

    func testPurposeContentTypeAndNonstandardPortChangeFraming() throws {
        let digest = Data(repeating: 7, count: 32)
        let origin = try FoundationFixture.origin()
        let first = try hash(origin: origin, purpose: .registration, contentType: "application/json", digest: digest)
        XCTAssertNotEqual(first, try hash(origin: origin, purpose: .token, contentType: "application/json", digest: digest))
        XCTAssertNotEqual(first, try hash(origin: origin, purpose: .registration, contentType: "application/json; charset=utf-8", digest: digest))
        XCTAssertNotEqual(first, try hash(
            origin: NovaAuthOrigin("https://example.com:8443"),
            purpose: .registration,
            contentType: "application/json",
            digest: digest
        ))
        XCTAssertThrowsError(try hash(origin: origin, purpose: .registration, contentType: "application/json ", digest: digest))
        XCTAssertThrowsError(try hash(origin: origin, purpose: .registration, contentType: "application/json", digest: Data()))
    }

    private func hash(origin: NovaAuthOrigin, purpose: NovaAuthPurpose, contentType: String, digest: Data) throws -> Data {
        try NovaAuthFraming.clientDataHash(
            challenge: FoundationFixture.challenge,
            clientID: FoundationFixture.clientID,
            origin: origin,
            purpose: purpose,
            contentType: contentType,
            bodyDigest: digest
        )
    }

    private func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
}

private struct Fixture: Decodable {
    let vectors: [Vector]
    struct Vector: Decodable {
        let name: String
        let context: Context
        let binding: Binding?
        let registration_preimage_hex: String?
        let issuance_preimage_hex: String?
        let body_sha256: String
        let preimage_hex: String
        let context_sha256: String
        let client_data_hash_base64: String
    }

    struct Context: Decodable { let challenge: String; let client_id: String; let authority: String; let content_type: String }
    struct Binding: Decodable { let app_id: String; let key_reference: String }
}
