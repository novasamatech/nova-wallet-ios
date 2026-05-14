import XCTest
@testable import novawallet

class StakingKeywordMatcherTests: XCTestCase {
    func testEmptyAndWhitespaceQueriesReturnFalse() {
        XCTAssertFalse(StakingKeywordMatcher.matches(query: ""))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "   "))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "\n\t"))
    }

    func testEnglishExactMatch() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "staking"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "validator"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "apy"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "polkadot staking"))
    }

    func testEnglishCaseInsensitive() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "STAKING"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "Validator"))
    }

    func testEnglishWhitespaceTrimmed() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "  staking  "))
    }

    func testEnglishPrefixMatch() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "staking apy"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "validator selection"))
    }

    // English keywords intentionally use exact-or-prefix matching to avoid
    // false positives on common short words. Mid-string English queries
    // should NOT trigger.
    func testEnglishMidStringDoesNotMatch() {
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "best staking option"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "where can i find a validator"))
    }

    func testFalsePositiveExclusions() {
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "stakeholder"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "stakeholder meeting"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "mistake"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "validate email"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "james bond"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "sweepstake winner"))
    }

    func testRussianExactAndMidString() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "стейкинг"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "валидатор"))
        // mid-string substring match (NEW after fix)
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "что такое стейкинг"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "лучшие валидаторы"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "как делать стейкинг"))
    }

    func testTurkishExactAndAgglutinated() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "stake yapmak"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "ödüller"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "doğrulayıcı"))
        // mid-string + agglutination
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "en iyi doğrulayıcılar"))
    }

    func testJapaneseSubstringMatch() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "ステーキング"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "ステーキング 方法"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "Polkadotステーキング"))
    }

    func testKoreanSubstringMatch() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "스테이킹"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "DOT 스테이킹"))
    }

    func testChineseSubstringMatch() {
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "质押"))
        XCTAssertTrue(StakingKeywordMatcher.matches(query: "如何质押"))
    }

    func testNonStakingQueriesReturnFalse() {
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "weather today"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "uniswap"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "swap dot"))
        XCTAssertFalse(StakingKeywordMatcher.matches(query: "nft marketplace"))
    }
}
