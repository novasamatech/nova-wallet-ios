import XCTest
@testable import NovaAnalytics

final class AnalyticsWirePayloadPolicyTests: XCTestCase {
    private func makeRow(
        identifier: String = AnalyticsPendingEvent.identifier(for: 1),
        name: String = "nova_card_opened",
        payload: String = "{}"
    ) -> AnalyticsPendingEvent {
        AnalyticsPendingEvent(
            identifier: identifier,
            sequence: 1,
            name: name,
            timestamp: Date(timeIntervalSince1970: 1_788_343_200.123),
            payload: Data(payload.utf8)
        )
    }

    private func assertPoison(
        _ row: AnalyticsPendingEvent,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try AnalyticsWirePayloadPolicy.vet(row), file: file, line: line) { error in
            XCTAssertTrue(error is AnalyticsWirePayloadPolicyError, "\(error)", file: file, line: line)
        }
    }

    private func enumeratedValues<T: CaseIterable & RawRepresentable>(
        _: T.Type
    ) -> [String] where T.RawValue == String {
        T.allCases.map(\.rawValue)
    }

    func testWellFormedRowBecomesTheWireEvent() throws {
        let row = makeRow(identifier: "row-1", payload: #"{"asset":"DOT","is_cross_chain":false}"#)

        XCTAssertEqual(
            try AnalyticsWirePayloadPolicy.vet(row),
            AnalyticsEventRemote(
                id: "row-1",
                name: "nova_card_opened",
                timestamp: "2026-09-02T10:00:00.123Z",
                props: ["asset": .string("DOT"), "is_cross_chain": .bool(false)]
            )
        )
    }

    func testMintedIdentifierPassesTheGate() throws {
        XCTAssertNoThrow(try AnalyticsWirePayloadPolicy.vet(makeRow()))
    }

    func testNumericValuePassesTheGate() throws {
        XCTAssertEqual(
            try AnalyticsWirePayloadPolicy.vet(makeRow(payload: #"{"nft_count":3}"#)).props,
            ["nft_count": .int(3)]
        )
    }

    func testEveryBoundaryCharacterPassesTheGate() throws {
        let payload = #"{"k":"AZaz09 ._:-"}"#

        XCTAssertEqual(
            try AnalyticsWirePayloadPolicy.vet(makeRow(payload: payload)).props,
            ["k": .string("AZaz09 ._:-")]
        )
    }

    func testSixtyFourCharacterValuePassesTheGate() throws {
        let value = String(repeating: "a", count: 64)

        XCTAssertNoThrow(try AnalyticsWirePayloadPolicy.vet(makeRow(payload: #"{"k":"\#(value)"}"#)))
    }

    func testFreeTextValueMarksTheRowAsPoison() {
        assertPoison(makeRow(payload: #"{"asset":"my savings wallet!"}"#))
    }

    func testUnicodeValueMarksTheRowAsPoison() {
        assertPoison(makeRow(payload: #"{"asset":"DÖT"}"#))
    }

    func testKelvinSignValueMarksTheRowAsPoison() {
        assertPoison(makeRow(payload: #"{"asset":"\#("\u{212A}")SM"}"#))
    }

    func testOverlongValueMarksTheRowAsPoison() {
        assertPoison(makeRow(payload: #"{"k":"\#(String(repeating: "a", count: 65))"}"#))
    }

    func testEmptyValueMarksTheRowAsPoison() {
        assertPoison(makeRow(payload: #"{"k":""}"#))
    }

    func testFreeTextKeyMarksTheRowAsPoison() {
        assertPoison(makeRow(payload: #"{"e-mail address?":"x"}"#))
    }

    func testFreeTextNameMarksTheRowAsPoison() {
        assertPoison(makeRow(name: "user@example.com"))
    }

    func testFreeTextIdentifierMarksTheRowAsPoison() {
        assertPoison(makeRow(identifier: "row 1 (alice)"))
    }

    func testNestedPayloadIsNotSendable() {
        XCTAssertThrowsError(try AnalyticsWirePayloadPolicy.vet(makeRow(payload: #"{"a":{"b":1}}"#)))
    }

    func testUndecodablePayloadIsNotSendable() {
        XCTAssertThrowsError(try AnalyticsWirePayloadPolicy.vet(makeRow(payload: "not-json")))
    }

    func testEveryDeclaredNameAndKeyFitsTheBoundaryGrammar() {
        let declared = AnalyticsEventName.allCases.map(\.rawValue) + AnalyticsPropertyKey.allCases.map(\.rawValue)

        for value in declared {
            XCTAssertTrue(AnalyticsWirePayloadPolicy.grammar.accepts(value), value)
        }
    }

    func testEveryEnumeratedValueFitsTheBoundaryGrammar() {
        let values = enumeratedValues(AssetCategory.self)
            + enumeratedValues(WalletCreationMethod.self)
            + enumeratedValues(SwapSource.self)
            + enumeratedValues(SwapFailureReason.self)
            + enumeratedValues(StakingStage.self)
            + enumeratedValues(SwapStage.self)
            + enumeratedValues(FeatureId.self)
            + enumeratedValues(OnboardingSource.self)
            + enumeratedValues(WalletCreationStep.self)
            + enumeratedValues(SignSource.self)
            + enumeratedValues(AnalyticsTab.self)
            + enumeratedValues(StakingAnalyticsType.self)
            + enumeratedValues(TransactionFailureReason.self)
            + enumeratedValues(SignFailureReason.self)
            + enumeratedValues(DAppOpenSource.self)
            + enumeratedValues(VoteDirection.self)
            + enumeratedValues(ConvictionLevel.self)
            + enumeratedValues(StakingFlowSource.self)
            + enumeratedValues(AnalyticsBannerScreen.self)
            + enumeratedValues(AmountBucket.self)
            + enumeratedValues(DurationBucket.self)
            + enumeratedValues(SlippageBucket.self)

        XCTAssertEqual(values.count, 102)

        for value in values {
            XCTAssertTrue(AnalyticsWirePayloadPolicy.grammar.accepts(value), value)
        }
    }
}
