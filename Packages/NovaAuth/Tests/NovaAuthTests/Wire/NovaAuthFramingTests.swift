import XCTest
import CryptoKit
@testable import NovaAuth

final class NovaAuthFramingTests: XCTestCase {
    func testProfile3VectorsReproduceTheServerFixtureByteForByte() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "profile-3-ios-vectors", withExtension: "json"))
        let fixture = try JSONDecoder().decode(FramingFixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.vectors.count, 2)
        for vector in fixture.vectors {
            let origin = try NovaAuthOrigin("https://" + vector.context.authority)
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
            let purpose: NovaAuthPurpose = vector.binding == nil ? .token : .registration
            let context = vector.context
            let preimage = try NovaAuthFraming.preimage(
                challenge: context.challenge, clientID: context.client_id, origin: origin,
                purpose: purpose, contentType: context.content_type, bodyDigest: digest
            )
            XCTAssertEqual(hex(preimage), vector.preimage_hex)
            let clientDataHash = try NovaAuthFraming.clientDataHash(
                challenge: context.challenge, clientID: context.client_id, origin: origin,
                purpose: purpose, contentType: context.content_type, bodyDigest: digest
            )
            XCTAssertEqual(hex(clientDataHash), vector.context_sha256)
            XCTAssertEqual(clientDataHash.base64EncodedString(), vector.client_data_hash_base64)
        }
    }

    private func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
}

private struct FramingFixture: Decodable {
    struct Context: Decodable { let challenge, client_id, authority, content_type: String }
    struct Binding: Decodable { let app_id, key_reference: String }
    struct Vector: Decodable {
        let context: Context
        let binding: Binding?
        let registration_preimage_hex, issuance_preimage_hex: String?
        let body_sha256, preimage_hex, context_sha256, client_data_hash_base64: String
    }

    let vectors: [Vector]
}
