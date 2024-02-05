import XCTest
import Foundation
@testable import novawallet

final class PushNotificationParsingTests: XCTestCase {
    func testParsingSettings() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .firestore()
        let url = json("firestore-settings")!
        let data = try Data(contentsOf: url)
        let settings = try decoder.decode(PushSettings.self, from: data)
        XCTAssertEqual(settings.pushToken, "test-token")
        XCTAssertEqual(settings.wallets.count, 1)
    }
    
    private func json(_ name: String) -> URL? {
        guard let path = Bundle(for: Self.self).path(forResource: name, ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}
