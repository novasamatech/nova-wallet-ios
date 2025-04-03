import XCTest
@testable import novawallet

final class XcmUniCodingTests: XCTestCase {

    func testVersionedEncoding() throws {
        // given
        
        let versioned = XcmUni.Versioned(entity: 1, version: .V5)
        
        // then
        
        let encoded = try JSONEncoder().encode(versioned)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        // then
        
        XCTAssertEqual("[\"V5\",1]", encodedString)
    }
    
    func testVersionedDecodingArray() throws {
        // given
        
        let encodedString = "[\"V5\", [[1, 2], [3, 4], [5, 6, 7]]]"
        let encoded = encodedString.data(using: .utf8)!
        
        let expected = XcmUni.Versioned<[[Int]]>(entity: [[1, 2], [3, 4], [5, 6, 7]], version: .V5)
        
        // then
        
        let versioned = try JSONDecoder().decode(XcmUni.Versioned<[[Int]]>.self, from: encoded)
        
        // then
        
        XCTAssertEqual(expected, versioned)
    }
}

extension Int: XcmUniCodable {
    public init(from decoder: Decoder, version: Xcm.Version) throws {
        try self.init(from: decoder)
    }
    
    public func encode(to encoder: Encoder, version: Xcm.Version) throws {
        try encode(to: encoder)
    }
}
