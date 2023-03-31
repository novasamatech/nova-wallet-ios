import XCTest
@testable import novawallet

final class MultibaseTests: XCTestCase {

    func testBase16Decoding() {
        testDecoding(string: "f68656c6c6f20776F726C64", expected: "hello world")
    }
    
    func testBase16UpperDecoding() {
        testDecoding(string: "F68656c6c6f20776F726C64", expected: "hello world")
    }
    
    func testBase32Decoding() {
        testDecoding(string: "bnbswy3dpeB3W64TMMQ", expected: "hello world")
    }
    
    func testBase32UpperDecoding() {
        testDecoding(string: "Bnbswy3dpeB3W64TMMQ", expected: "hello world")
    }
    
    func testBase32hexDecoding() {
        testDecoding(string: "vd1imor3f41RMUSJCCG", expected: "hello world")
    }
    
    func testBase32hexUpperDecoding() {
        testDecoding(string: "Vd1imor3f41RMUSJCCG", expected: "hello world")
    }
    
    func testBase32padDecoding() {
        testDecoding(string: "cnbswy3dpeB3W64TMMQ", expected: "hello world")
    }
    
    func testBase32padUpperDecoding() {
        testDecoding(string: "Cnbswy3dpeB3W64TMMQ", expected: "hello world")
    }
    
    func testBase32hexPadDecoding() {
        testDecoding(string: "td1imor3f41RMUSJCCG======", expected: "hello world")
    }
    
    func testBase32hexPadUpperDecoding() {
        testDecoding(string: "Td1imor3f41RMUSJCCG======", expected: "hello world")
    }
    
    func testBase36Decoding() {
        testDecoding(string: "kfUvrsIvVnfRbjWaJo", expected: "hello world")
    }
    
    func testBase36UpperDecoding() {
        testDecoding(string: "KfUVrSIVVnFRbJWAJo", expected: "hello world")
    }
    
    private func testDecoding(string: String, expected expectedString: String) {
        let decoded = decodeMultibase(string)
        XCTAssertEqual(decoded.map { String(data: $0, encoding: .utf8) }, expectedString)
    }

}
