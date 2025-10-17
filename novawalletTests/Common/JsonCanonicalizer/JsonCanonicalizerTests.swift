import XCTest
@testable import novawallet

final class JsonCanonicalizerTests: XCTestCase {
    func testJsonCanonicalizerFrench() throws {
        try testJsonCanonicalizer(sample: .french)
    }

    func testJsonCanonicalizerArrays() throws {
        try testJsonCanonicalizer(sample: .arrays)
    }

    func testJsonCanonicalizerWeird() throws {
        try testJsonCanonicalizer(sample: .weird)
    }

    func testJsonCanonicalizerStructures() throws {
        try testJsonCanonicalizer(sample: .structures)
    }

    private func testJsonCanonicalizer(sample: Sample) throws {
        let canonicalizer = JsonCanonicalizer()
        let url = json(sample.input)!
        let data = try Data(contentsOf: url)
        let result = try canonicalizer.canonicalizeJSON(data)

        let expectedUrl = json(sample.output)!
        let expectedData = try Data(contentsOf: expectedUrl)
        let expectedResult = String(data: expectedData, encoding: .utf8)!.trimmingCharacters(in: .newlines)

        XCTAssertEqual(result, expectedResult)
    }

    private func json(_ name: String) -> URL? {
        guard let path = Bundle(for: Self.self).path(forResource: name, ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}

private enum Sample: String {
    case french
    case arrays
    case weird
    case structures

    var input: String { [rawValue, "input"].joined(separator: "_") }
    var output: String { [rawValue, "output"].joined(separator: "_") }
}
