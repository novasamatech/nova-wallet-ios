import XCTest
@testable import novawallet

class RecommendationsComposerTests: XCTestCase {
    let allValidators: [ElectedValidatorInfo] = [
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr1",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: nil,
            stakeReturn: 0.9,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),

        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(
                name: "val1",
                parentAddress: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
                parentName: nil,
                identity: nil
            ),
            stakeReturn: 0.5,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr9",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val4"),
            stakeReturn: 0.1,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val2"),
            stakeReturn: 0.6,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ),

        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e8pnr9",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val5"),
            stakeReturn: 0.9,
            hasSlashes: true,
            maxNominatorsRewarded: 128,
            blocked: false
        ),

        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo7Bfv8Ff6e8pnr9",
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "val5"),
            stakeReturn: 0.9,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: true
        )
    ]

    func testClusterRemovalAndFilters() {
        // given

        let expectedValidators: [SelectedValidatorInfo] = [
            ElectedValidatorInfo(
                address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
                nominators: [],
                totalStake: 10,
                ownStake: 10,
                comission: 0.0,
                identity: AccountIdentity(name: "val2"),
                stakeReturn: 0.6,
                hasSlashes: false,
                maxNominatorsRewarded: 128,
                blocked: false
            ),
            ElectedValidatorInfo(
                address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr9",
                nominators: [],
                totalStake: 10,
                ownStake: 10,
                comission: 0.0,
                identity: AccountIdentity(name: "val4"),
                stakeReturn: 0.1,
                hasSlashes: false,
                maxNominatorsRewarded: 128,
                blocked: false
            )
        ].map { $0.toSelected(for: nil) }

        let composer = RecommendationsComposer(resultSize: 10, clusterSizeLimit: 1)

        // when

        let result = composer.compose(from: allValidators.map { $0.toSelected(for: nil) }, preferrences: [])

        // then

        XCTAssertEqual(expectedValidators, result)
    }

    func testMaxSizeApplied() {
        // given

        let expectedValidators: [SelectedValidatorInfo] = [
            ElectedValidatorInfo(
                address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr7",
                nominators: [],
                totalStake: 10,
                ownStake: 10,
                comission: 0.0,
                identity: AccountIdentity(name: "val2"),
                stakeReturn: 0.6,
                hasSlashes: false,
                maxNominatorsRewarded: 128,
                blocked: false
            )
        ].map { $0.toSelected(for: nil) }

        let composer = RecommendationsComposer(resultSize: 1, clusterSizeLimit: 1)

        // when

        let result = composer.compose(from: allValidators.map { $0.toSelected(for: nil) }, preferrences: [])

        // then

        XCTAssertEqual(expectedValidators, result)
    }

    func testRecommendedAndPreferredValidators() {
        // given

        let composer = RecommendationsComposer(resultSize: 2, clusterSizeLimit: 1)

        let generator = CustomValidatorListTestDataGenerator.self

        let preferred = generator.poorGoodValidator.toSelected(for: nil)
        let recommended1 = generator.goodValidator.toSelected(for: nil)
        let recommended2 = generator.greedyGoodValidator.toSelected(for: nil)

        let recommendations = composer.compose(from: [recommended1, recommended2], preferrences: [preferred])

        XCTAssertEqual(recommendations.count, composer.resultSize)
        XCTAssertTrue(recommendations.contains(where: { $0.address == preferred.address }))
    }

    func testPreferredOversubscribedNotIncludedValidators() {
        // given

        let composer = RecommendationsComposer(resultSize: 2, clusterSizeLimit: 1)

        let generator = CustomValidatorListTestDataGenerator.self

        let preferred = generator.oversubscribedValidator.toSelected(for: nil)
        let recommended1 = generator.goodValidator.toSelected(for: nil)
        let recommended2 = generator.greedyGoodValidator.toSelected(for: nil)

        let recommendations = composer.compose(from: [recommended1, recommended2], preferrences: [preferred])

        let expectedResult = [recommended1, recommended2].sorted { $0.stakeReturn > $1.stakeReturn }

        XCTAssertEqual(recommendations, expectedResult)
    }

    func testOnlyPreferredValidators() {
        // given

        let composer = RecommendationsComposer(resultSize: 2, clusterSizeLimit: 1)

        let generator = CustomValidatorListTestDataGenerator.self

        let preferred = generator.clusterValidatorChild1.toSelected(for: nil)

        let recommendations = composer.compose(from: [], preferrences: [preferred])

        XCTAssertEqual(recommendations, [preferred])
    }

    func testOnlyPreferredWithAvailableRecommendedValidators() {
        // given

        let composer = RecommendationsComposer(resultSize: 2, clusterSizeLimit: 1)

        let generator = CustomValidatorListTestDataGenerator.self

        let recommended1 = generator.goodValidator.toSelected(for: nil)
        let preferred1 = generator.clusterValidatorChild1.toSelected(for: nil)
        let preferred2 = generator.clusterValidatorChild1.toSelected(for: nil)
        let preferred3 = generator.clusterValidatorChild1.toSelected(for: nil)

        let preferredList = [preferred1, preferred2, preferred3]
        let recommendations = composer.compose(from: [recommended1], preferrences: preferredList)

        let expectedList = [preferred1, preferred2]

        XCTAssertEqual(recommendations, expectedList)
    }

    // A preferred validator that also ranks into the recommendation list must keep its slot:
    // it sits at the tail by stakeReturn, exactly where truncation used to silently drop it.
    func testPreferredInsideRecommendationListSurvivesTruncation() {
        // given

        let composer = RecommendationsComposer(resultSize: 3, clusterSizeLimit: 1)

        let topCommunity = Self.makeValidator(suffix: "A", stakeReturn: 0.9)
        let midCommunity = Self.makeValidator(suffix: "B", stakeReturn: 0.7)
        let preferredInside = Self.makeValidator(suffix: "C", stakeReturn: 0.05)
        let preferredOutside = Self.makeValidator(suffix: "D", stakeReturn: 0.5)

        // when

        let recommendations = composer.compose(
            from: [preferredInside, topCommunity, midCommunity],
            preferrences: [preferredInside, preferredOutside]
        )

        // then

        XCTAssertEqual(recommendations.count, composer.resultSize)
        XCTAssertTrue(recommendations.contains(where: { $0.address == preferredInside.address }))
        XCTAssertTrue(recommendations.contains(where: { $0.address == preferredOutside.address }))
        XCTAssertEqual(
            recommendations.map(\.address),
            [topCommunity, preferredInside, preferredOutside].map(\.address)
        )
    }

    func testEmptyPreferencesKeepRecommendationListUnchanged() {
        // given

        let composer = RecommendationsComposer(resultSize: 2, clusterSizeLimit: 1)

        let best = Self.makeValidator(suffix: "A", stakeReturn: 0.9)
        let second = Self.makeValidator(suffix: "B", stakeReturn: 0.7)
        let third = Self.makeValidator(suffix: "C", stakeReturn: 0.5)
        let worst = Self.makeValidator(suffix: "D", stakeReturn: 0.05)

        // when

        let recommendations = composer.compose(from: [worst, second, best, third], preferrences: [])

        // then

        XCTAssertEqual(recommendations.map(\.address), [best, second].map(\.address))
    }
}

private extension RecommendationsComposerTests {
    static func makeValidator(suffix: String, stakeReturn: Decimal) -> SelectedValidatorInfo {
        ElectedValidatorInfo(
            address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr" + suffix,
            nominators: [],
            totalStake: 10,
            ownStake: 10,
            comission: 0.0,
            identity: AccountIdentity(name: "Validator " + suffix),
            stakeReturn: stakeReturn,
            hasSlashes: false,
            maxNominatorsRewarded: 128,
            blocked: false
        ).toSelected(for: nil)
    }
}
