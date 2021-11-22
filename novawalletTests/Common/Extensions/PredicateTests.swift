import XCTest
@testable import novawallet

class PredicateTests: XCTestCase {

    func testDerivationPathPredicate() {
        XCTAssertTrue(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "/1//2///3"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "/привет//мир///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "//hard"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "/soft"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: ""))

        XCTAssertFalse(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "/soft/"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "/soft//"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "////hard"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: "/soft//hard///"))
    }

    func testDerivationPathHardSoftPredicate() {
        XCTAssertTrue(NSPredicate.deriviationPathHardSoft.evaluate(with: "/1//2"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoft.evaluate(with: "/привет//мир"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoft.evaluate(with: "//hard"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoft.evaluate(with: "/soft"))
        XCTAssertTrue(NSPredicate.deriviationPathHardSoft.evaluate(with: ""))

        XCTAssertFalse(NSPredicate.deriviationPathHardSoft.evaluate(with: "soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoft.evaluate(with: "/soft/"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoft.evaluate(with: "/soft//"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoft.evaluate(with: "/soft///password"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoft.evaluate(with: "////hard"))
        XCTAssertFalse(NSPredicate.deriviationPathHardSoft.evaluate(with: "/soft//hard///"))
    }

    func testDerivationPathHardPredicate() {
        XCTAssertTrue(NSPredicate.deriviationPathHard.evaluate(with: "//2"))
        XCTAssertTrue(NSPredicate.deriviationPathHard.evaluate(with: "//мир"))
        XCTAssertTrue(NSPredicate.deriviationPathHard.evaluate(with: "//hard"))
        XCTAssertTrue(NSPredicate.deriviationPathHard.evaluate(with: "//hard//soft"))
        XCTAssertTrue(NSPredicate.deriviationPathHard.evaluate(with: ""))

        XCTAssertFalse(NSPredicate.deriviationPathHard.evaluate(with: "soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHard.evaluate(with: "/soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHard.evaluate(with: "//soft//"))
        XCTAssertFalse(NSPredicate.deriviationPathHard.evaluate(with: "//soft///password"))
        XCTAssertFalse(NSPredicate.deriviationPathHard.evaluate(with: "///hard"))
        XCTAssertFalse(NSPredicate.deriviationPathHard.evaluate(with: "//hard///"))
    }

    func testDerivationPathHardPasswordPredicate() {
        XCTAssertTrue(NSPredicate.deriviationPathHardPassword.evaluate(with: "//2///3"))
        XCTAssertTrue(NSPredicate.deriviationPathHardPassword.evaluate(with: "//мир//привет///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPathHardPassword.evaluate(with: "///пароль"))
        XCTAssertTrue(NSPredicate.deriviationPathHardPassword.evaluate(with: "//hard"))
        XCTAssertTrue(NSPredicate.deriviationPathHardPassword.evaluate(with: ""))

        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "/soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "//hard/soft"))
        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "//hard/soft///password"))
        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "/soft//"))
        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "////hard"))
        XCTAssertFalse(NSPredicate.deriviationPathHardPassword.evaluate(with: "/soft//hard///"))
    }

    func testSeedPredicate() {
        XCTAssertTrue(NSPredicate.substrateSeed.evaluate(with: "2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac"))
        XCTAssertTrue(NSPredicate.substrateSeed.evaluate(with: "0x2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac"))

        XCTAssertFalse(NSPredicate.substrateSeed.evaluate(with: "0x2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961"))
        XCTAssertFalse(NSPredicate.substrateSeed.evaluate(with: "2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961"))
        XCTAssertFalse(NSPredicate.substrateSeed.evaluate(with: "2x02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed99696123"))
        XCTAssertFalse(NSPredicate.substrateSeed.evaluate(with: ""))
    }

    func testWebsocketPredicate() {
        XCTAssertTrue(NSPredicate.websocket.evaluate(with: "wss://cc3-5.kusama.network"))
        XCTAssertTrue(NSPredicate.websocket.evaluate(with: "ws://cc3-5.kusama.network"))
        XCTAssertTrue(NSPredicate.websocket.evaluate(with: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443"))
        XCTAssertTrue(NSPredicate.websocket.evaluate(with: "wss://48.1.1.2/"))
        XCTAssertTrue(NSPredicate.websocket.evaluate(with: "ws://142.42.1.1:8080/"))

        XCTAssertFalse(NSPredicate.websocket.evaluate(with: "wss://??"))
        XCTAssertFalse(NSPredicate.websocket.evaluate(with: "wss://foo.bar?q=Spaces should be encoded"))
        XCTAssertFalse(NSPredicate.websocket.evaluate(with: "wss://10.1.1.255"))
    }
}
