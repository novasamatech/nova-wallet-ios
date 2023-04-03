import XCTest
@testable import novawallet

final class MultibaseTests: XCTestCase {

    func testBase2Decoding() {
        testDecoding(string: "001111001011001010111001100100000011011010110000101101110011010010010000000100001", expected: "yes mani !")
    }
    
    func testBase8Decoding() {
        testDecoding(string: "7362625631006654133464440102", expected: "yes mani !")
    }
    
    func testBase10Decoding() {
        testDecoding(string: "9573277761329450583662625", expected: "yes mani !")
    }
    
    func testBase16Decoding() {
        testDecoding(string: "f68656c6c6f20776F726C64", expected: "hello world")
        testDecoding(string: "f796573206d616e692021", expected: "yes mani !")
    }
    
    func testBase16UpperDecoding() {
        testDecoding(string: "F68656c6c6f20776F726C64", expected: "hello world")
        testDecoding(string: "F796573206D616E692021", expected: "yes mani !")
    }
    
    func testBase32Decoding() {
        testDecoding(string: "bnbswy3dpeB3W64TMMQ", expected: "hello world")
        testDecoding(string: "bpfsxgidnmfxgsibb", expected: "yes mani !")
    }
    
    func testBase32UpperDecoding() {
        testDecoding(string: "Bnbswy3dpeB3W64TMMQ", expected: "hello world")
        testDecoding(string: "BPFSXGIDNMFXGSIBB", expected: "yes mani !")
    }
    
    func testBase32hexDecoding() {
        testDecoding(string: "vd1imor3f41RMUSJCCG", expected: "hello world")
        testDecoding(string: "vf5in683dc5n6i811", expected: "yes mani !")
    }
    
    func testBase32hexUpperDecoding() {
        testDecoding(string: "Vd1imor3f41RMUSJCCG", expected: "hello world")
        testDecoding(string: "VF5IN683DC5N6I811", expected: "yes mani !")
    }
    
    func testBase32padDecoding() {
        testDecoding(string: "cnbswy3dpeB3W64TMMQ======", expected: "hello world")
        testDecoding(string: "cpfsxgidnmfxgsibb", expected: "yes mani !")
    }
    
    func testBase32padUpperDecoding() {
        testDecoding(string: "Cnbswy3dpeB3W64TMMQ======", expected: "hello world")
        testDecoding(string: "CPFSXGIDNMFXGSIBB", expected: "yes mani !")
    }
    
    func testBase32hexPadDecoding() {
        testDecoding(string: "td1imor3f41RMUSJCCG======", expected: "hello world")
        testDecoding(string: "tf5in683dc5n6i811", expected: "yes mani !")
    }
    
    func testBase32hexPadUpperDecoding() {
        testDecoding(string: "Td1imor3f41RMUSJCCG======", expected: "hello world")
        testDecoding(string: "TF5IN683DC5N6I811", expected: "yes mani !")
    }
    
    func testBase32zDecoding() {
        testDecoding(string: "Td1imor3f41RMUSJCCG======", expected: "hello world")
        testDecoding(string: "hxf1zgedpcfzg1ebb", expected: "yes mani !")
    }
    
    func testBase36Decoding() {
        testDecoding(string: "kfUvrsIvVnfRbjWaJo", expected: "hello world")
        testDecoding(string: "k2lcpzo5yikidynfl", expected: "yes mani !")
    }
    
    func testBase36UpperDecoding() {
        testDecoding(string: "KfUVrSIVVnFRbJWAJo", expected: "hello world")
        testDecoding(string: "K2LCPZO5YIKIDYNFL", expected: "yes mani !")
    }
    
    func testBase58flickrDecoding() {
        testDecoding(string: "Z7Pznk19XTTzBtx", expected: "yes mani !")
    }
    
    func testBase58btcDecoding() {
        testDecoding(string: "z7paNL19xttacUY", expected: "yes mani !")
    }
    
    func testBase64Decoding() {
        testDecoding(string: "meWVzIG1hbmkgIQ", expected: "yes mani !")
    }
    
    func testBase64padDecoding() {
        testDecoding(string: "MeWVzIG1hbmkgIQ==", expected: "yes mani !")
    }
    
    func testBase64urlDecoding() {
        testDecoding(string: "ueWVzIG1hbmkgIQ", expected: "yes mani !")
    }
    
    func testBase64urlPadDecoding() {
        testDecoding(string: "UeWVzIG1hbmkgIQ==", expected: "yes mani !")
    }
    
    func testBase256emojiDecoding() {
        testDecoding(string: "🚀🏃✋🌈😅🌷🤤😻🌟😅👏", expected: "yes mani !")
    }
    
    private func testDecoding(string: String, expected expectedString: String) {
        let decoded = decodeMultibase(string)
        XCTAssertEqual(decoded.map { String(data: $0, encoding: .utf8) }, expectedString)
    }

}
