import XCTest
@testable import novawallet

class CustomValidatorListComposerTests: XCTestCase {
    func testDefaultFilter() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators
        )
        let expectedResult = allValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        let filter = CustomValidatorListFilter.defaultFilter()
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: [])

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testRecommendedFilter() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self

        let allValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators
        )

        let goodValidators = generator.createSelectedValidators(from: generator.goodValidators)

        let expectedResult = goodValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        let filter = CustomValidatorListFilter.recommendedFilter(havingIdentity: true)
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: [])

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testSort() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = generator.createSelectedValidators(from: generator.goodValidators)
        let expectedResult = allValidators.sorted {
            $0.ownStake >= $1.ownStake
        }

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.sortedBy = .ownStake
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: [])

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testClustersRemoval() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = generator
            .createSelectedValidators(from: generator.clusterValidators)
        let expectedResult = [
            allValidators.sorted {
                $0.stakeReturn >= $1.stakeReturn
            }.first
        ]

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.allowsClusters = .limited(amount: 1)
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: [])

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testSlashesRemoval() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                [generator.slashedValidator]
        )

        let goodValidators = generator
            .createSelectedValidators(from: generator.goodValidators)

        let expectedResult = goodValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.allowsSlashed = false
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: [])

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testTwoFilterCriteria() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators +
                generator.clusterValidators
        )

        let expectedValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                [generator.noIdentityValidator] +
                generator.clusterValidators
        )

        let expectedResult = expectedValidators.sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        var filter = CustomValidatorListFilter.defaultFilter()
        filter.allowsSlashed = false
        filter.allowsOversubscribed = false
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: [])

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testDefaultFilterWithPreferrences() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self
        let allValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators
        )

        let preferences = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let expectedResult = (allValidators + preferences).sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        let filter = CustomValidatorListFilter.defaultFilter()
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: preferences)

        // then

        XCTAssertEqual(result, expectedResult)
    }

    func testRecommendedFilterWithPreferrences() {
        // given
        let generator = CustomValidatorListTestDataGenerator.self

        let allValidators = generator.createSelectedValidators(
            from: generator.goodValidators +
                generator.badValidators
        )

        let goodValidators = generator.createSelectedValidators(from: generator.goodValidators)

        let preferrences = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let expectedResult = (goodValidators + preferrences).sorted {
            $0.stakeReturn >= $1.stakeReturn
        }

        let filter = CustomValidatorListFilter.recommendedFilter(havingIdentity: true)
        let composer = CustomValidatorListComposer(filter: filter)

        // when

        let result = composer.compose(from: allValidators, preferrences: preferrences)

        // then

        XCTAssertEqual(result, expectedResult)
    }
}
