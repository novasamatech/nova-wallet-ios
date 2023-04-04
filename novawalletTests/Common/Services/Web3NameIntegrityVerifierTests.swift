import XCTest
@testable import novawallet

final class Web3NameIntegrityVerifierTests: XCTestCase {
    private let verifier = Web3NameIntegrityVerifier()
    
    func testCorectHash() throws {
        let serviceEndpointId = "did:kilt:4pqDzaWi3w7TzYzGnQDyrasK6UnyNnW6JQvWRrq6r8HzNNGy#\(Sample.hash)"
        let url = json(Sample.resource)!
        let data = try Data(contentsOf: url)
        let serviceEndpointContent = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = verifier.verify(serviceEndpointId: serviceEndpointId,
                                     serviceEndpointContent: serviceEndpointContent)
        XCTAssertEqual(result, true)
    }
    
    func testInvalidHash() throws {
        let serviceEndpointId = "did:kilt:4pqDzaWi3w7TzYzGnQDyrasK6UnyNnW6JQvWRrq6r8HzNNGy#Uinvalid-hash="
        let url = json(Sample.resource)!
        let data = try Data(contentsOf: url)
        let serviceEndpointContent = String(data: data, encoding: .utf8)!
        let result = verifier.verify(serviceEndpointId: serviceEndpointId,
                                     serviceEndpointContent: serviceEndpointContent)
        XCTAssertEqual(result, false)
    }
    
    private func json(_ name: String) -> URL? {
        guard let path = Bundle(for: Self.self).path(forResource: name, ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}

private enum Sample {
    static let hash = "UdY8PA3eq8NgtWvyRctUhskMAdsY9XHE1mhGzMYMcsDA="
    static let resource = "kilt-addresses"
}
