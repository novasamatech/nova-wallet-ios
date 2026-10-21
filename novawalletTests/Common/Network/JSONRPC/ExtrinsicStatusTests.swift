@testable import novawallet
import XCTest

final class ExtrinsicStatusTests: XCTestCase {
    func testEveryPoolStatusShapeDecodesFromTheWatchUpdate() throws {
        XCTAssertEqual(try decodeStatus("\"future\""), .future)
        XCTAssertEqual(try decodeStatus("\"ready\""), .ready)
        XCTAssertEqual(try decodeStatus("{\"broadcast\":[\"12D3KooWPeer\"]}"), .broadcast(["12D3KooWPeer"]))
        XCTAssertEqual(try decodeStatus("{\"retracted\":\"0x01\"}"), .retracted("0x01"))
        XCTAssertEqual(try decodeStatus("{\"usurped\":\"0x02\"}"), .usurped("0x02"))
        XCTAssertEqual(try decodeStatus("\"dropped\""), .dropped)
        XCTAssertEqual(try decodeStatus("\"invalid\""), .invalid)
    }

    private func decodeStatus(_ result: String) throws -> ExtrinsicStatus {
        let update = """
        {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"7","result":\(result)}}
        """

        return try JSONDecoder().decode(ExtrinsicSubscriptionUpdate.self, from: Data(update.utf8)).params.result
    }
}
