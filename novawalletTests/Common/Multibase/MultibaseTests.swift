import XCTest
@testable import novawallet

final class MultibaseTests: XCTestCase {
    func testBase2Decoding() {
        testDecoding(string: "001111001011001010111001100100000011011010110000101101110011010010010000000100001", expected: "yes mani !")
        testDecoding(string: "00000000001111001011001010111001100100000011011010110000101101110011010010010000000100001", expected: "\0yes mani !")
        testDecoding(string: "0000000000000000001111001011001010111001100100000011011010110000101101110011010010010000000100001", expected: "\0\0yes mani !")
    }

    func testBase8Decoding() {
        testDecoding(string: "7362625631006654133464440102", expected: "yes mani !")
        testDecoding(string: "7000745453462015530267151100204", expected: "\0yes mani !")
        testDecoding(string: "700000171312714403326055632220041", expected: "\0\0yes mani !")
    }

    func testBase10Decoding() {
        testDecoding(string: "9573277761329450583662625", expected: "yes mani !")
        testDecoding(string: "90573277761329450583662625", expected: "\0yes mani !")
        testDecoding(string: "900573277761329450583662625", expected: "\0\0yes mani !")
    }

    func testBase16Decoding() {
        testDecoding(string: "f68656c6c6f20776F726C64", expected: "hello world")
        testDecoding(string: "f796573206d616e692021", expected: "yes mani !")
        testDecoding(string: "f00796573206d616e692021", expected: "\0yes mani !")
        testDecoding(string: "f0000796573206d616e692021", expected: "\0\0yes mani !")
    }

    func testBase16UpperDecoding() {
        testDecoding(string: "F68656c6c6f20776F726C64", expected: "hello world")
        testDecoding(string: "F796573206D616E692021", expected: "yes mani !")
        testDecoding(string: "F00796573206D616E692021", expected: "\0yes mani !")
        testDecoding(string: "F0000796573206D616E692021", expected: "\0\0yes mani !")
    }

    func testBase32Decoding() {
        testDecoding(string: "bnbswy3dpeB3W64TMMQ", expected: "hello world")
        testDecoding(string: "bpfsxgidnmfxgsibb", expected: "yes mani !")
        testDecoding(string: "bab4wk4zanvqw42jaee", expected: "\0yes mani !")
        testDecoding(string: "baaahszltebwwc3tjeaqq", expected: "\0\0yes mani !")
    }

    func testBase32UpperDecoding() {
        testDecoding(string: "Bnbswy3dpeB3W64TMMQ", expected: "hello world")
        testDecoding(string: "BPFSXGIDNMFXGSIBB", expected: "yes mani !")
        testDecoding(string: "BAB4WK4ZANVQW42JAEE", expected: "\0yes mani !")
        testDecoding(string: "BAAAHSZLTEBWWC3TJEAQQ", expected: "\0\0yes mani !")
    }

    func testBase32hexDecoding() {
        testDecoding(string: "vd1imor3f41RMUSJCCG", expected: "hello world")
        testDecoding(string: "vf5in683dc5n6i811", expected: "yes mani !")
        testDecoding(string: "v01smasp0dlgmsq9044", expected: "\0yes mani !")
        testDecoding(string: "v0007ipbj41mm2rj940gg", expected: "\0\0yes mani !")
    }

    func testBase32hexUpperDecoding() {
        testDecoding(string: "Vd1imor3f41RMUSJCCG", expected: "hello world")
        testDecoding(string: "VF5IN683DC5N6I811", expected: "yes mani !")
        testDecoding(string: "V01SMASP0DLGMSQ9044", expected: "\0yes mani !")
        testDecoding(string: "V0007IPBJ41MM2RJ940GG", expected: "\0\0yes mani !")
    }

    func testBase32padDecoding() {
        testDecoding(string: "cnbswy3dpeB3W64TMMQ======", expected: "hello world")
        testDecoding(string: "cpfsxgidnmfxgsibb", expected: "yes mani !")
        testDecoding(string: "cab4wk4zanvqw42jaee======", expected: "\0yes mani !")
        testDecoding(string: "caaahszltebwwc3tjeaqq====", expected: "\0\0yes mani !")
    }

    func testBase32padUpperDecoding() {
        testDecoding(string: "Cnbswy3dpeB3W64TMMQ======", expected: "hello world")
        testDecoding(string: "CPFSXGIDNMFXGSIBB", expected: "yes mani !")
        testDecoding(string: "CAB4WK4ZANVQW42JAEE======", expected: "\0yes mani !")
        testDecoding(string: "CAAAHSZLTEBWWC3TJEAQQ====", expected: "\0\0yes mani !")
    }

    func testBase32hexPadDecoding() {
        testDecoding(string: "td1imor3f41RMUSJCCG======", expected: "hello world")
        testDecoding(string: "tf5in683dc5n6i811", expected: "yes mani !")
        testDecoding(string: "t01smasp0dlgmsq9044======", expected: "\0yes mani !")
        testDecoding(string: "t0007ipbj41mm2rj940gg====", expected: "\0\0yes mani !")
    }

    func testBase32hexPadUpperDecoding() {
        testDecoding(string: "Td1imor3f41RMUSJCCG======", expected: "hello world")
        testDecoding(string: "TF5IN683DC5N6I811", expected: "yes mani !")
        testDecoding(string: "T01SMASP0DLGMSQ9044======", expected: "\0yes mani !")
        testDecoding(string: "T0007IPBJ41MM2RJ940GG====", expected: "\0\0yes mani !")
    }

    func testBase32zDecoding() {
        testDecoding(string: "Td1imor3f41RMUSJCCG======", expected: "hello world")
        testDecoding(string: "hxf1zgedpcfzg1ebb", expected: "yes mani !")
        testDecoding(string: "hybhskh3ypiosh4jyrr", expected: "\0yes mani !")
        testDecoding(string: "hyyy813murbssn5ujryoo", expected: "\0\0yes mani !")
    }

    func testBase36Decoding() {
        testDecoding(string: "kfUvrsIvVnfRbjWaJo", expected: "hello world")
        testDecoding(string: "k2lcpzo5yikidynfl", expected: "yes mani !")
        testDecoding(string: "k02lcpzo5yikidynfl", expected: "\0yes mani !")
        testDecoding(string: "k002lcpzo5yikidynfl", expected: "\0\0yes mani !")
    }

    func testBase36UpperDecoding() {
        testDecoding(string: "KfUVrSIVVnFRbJWAJo", expected: "hello world")
        testDecoding(string: "K2LCPZO5YIKIDYNFL", expected: "yes mani !")
        testDecoding(string: "K02LCPZO5YIKIDYNFL", expected: "\0yes mani !")
        testDecoding(string: "K002LCPZO5YIKIDYNFL", expected: "\0\0yes mani !")
    }

    func testBase58flickrDecoding() {
        testDecoding(string: "Z7Pznk19XTTzBtx", expected: "yes mani !")
        testDecoding(string: "Z17Pznk19XTTzBtx", expected: "\0yes mani !")
        testDecoding(string: "Z117Pznk19XTTzBtx", expected: "\0\0yes mani !")
    }

    func testBase58btcDecoding() {
        testDecoding(string: "z7paNL19xttacUY", expected: "yes mani !")
        testDecoding(string: "z17paNL19xttacUY", expected: "\0yes mani !")
        testDecoding(string: "z117paNL19xttacUY", expected: "\0\0yes mani !")
    }

    func testBase64Decoding() {
        testDecoding(string: "meWVzIG1hbmkgIQ", expected: "yes mani !")
        testDecoding(string: "mAHllcyBtYW5pICE", expected: "\0yes mani !")
        testDecoding(string: "mAAB5ZXMgbWFuaSAh", expected: "\0\0yes mani !")
    }

    func testBase64padDecoding() {
        testDecoding(string: "MeWVzIG1hbmkgIQ==", expected: "yes mani !")
        testDecoding(string: "MAHllcyBtYW5pICE=", expected: "\0yes mani !")
        testDecoding(string: "MAAB5ZXMgbWFuaSAh", expected: "\0\0yes mani !")
    }

    func testBase64urlDecoding() {
        testDecoding(string: "ueWVzIG1hbmkgIQ", expected: "yes mani !")
        testDecoding(string: "uAHllcyBtYW5pICE", expected: "\0yes mani !")
        testDecoding(string: "uAAB5ZXMgbWFuaSAh", expected: "\0\0yes mani !")
    }

    func testBase64urlPadDecoding() {
        testDecoding(string: "UeWVzIG1hbmkgIQ==", expected: "yes mani !")
        testDecoding(string: "UAHllcyBtYW5pICE=", expected: "\0yes mani !")
        testDecoding(string: "UAAB5ZXMgbWFuaSAh", expected: "\0\0yes mani !")
    }

    private func testDecoding(string: String, expected expectedString: String) {
        let decoded = Data(multibaseEncoded: string)
        XCTAssertEqual(decoded.map { String(data: $0, encoding: .utf8) }, expectedString)
    }
}
