@testable import novawallet
import XCTest

final class BlockTimeSamplingTests: XCTestCase {
    // MARK: - Sampling

    func testElasticScalingTimestampsAverageToSlotDurationDividedByBlocksPerSlot() {
        // Hydration: 3 blocks per 6s relay slot, Timestamp.Now deltas are 0, 0, 6000
        let observations = (0 ... 60).map { block in (BlockNumber(block), BlockTime(block / 3) * 6000) }

        let result = EstimatedBlockTime.initial.feed(observations)

        XCTAssertEqual(result.blockTime, 2000)
        XCTAssertEqual(result.seqSize, 2)
    }

    func testRegularChainSamplesItsBlockTimeExactly() {
        let observations = (0 ... 30).map { block in (BlockNumber(block), BlockTime(block) * 6000) }

        let result = EstimatedBlockTime.initial.feed(observations)

        XCTAssertEqual(result.blockTime, 6000)
        XCTAssertEqual(result.seqSize, 1)
    }

    func testNoSampleUntilWindowSpansEnoughBlocks() {
        let observations = (0 ..< Int(BlockTimeSampling.windowBlocks)).map { block in
            (BlockNumber(block), BlockTime(block) * 6000)
        }

        let result = EstimatedBlockTime.initial.feed(observations)

        XCTAssertEqual(result.seqSize, 0)
        XCTAssertEqual(result.windowStartBlock, 0)
    }

    func testSkippedBlockNotificationsDoNotPreventSampling() {
        let observations = [0, 7, 19, 33].map { block in (BlockNumber(block), BlockTime(block) * 6000) }

        let result = EstimatedBlockTime.initial.feed(observations)

        XCTAssertEqual(result.blockTime, 6000)
        XCTAssertEqual(result.seqSize, 1)
    }

    func testWindowRestartsWhenBlockNumberGoesBackwards() {
        let observations: [(BlockNumber, BlockTime)] = [
            (100, 600_000),
            (90, 540_000), // reorg / different node
            (120, 720_000)
        ]

        let result = EstimatedBlockTime.initial.feed(observations)

        // Without a restart the window would be 100..120 (20 blocks) and produce nothing
        XCTAssertEqual(result.blockTime, 6000)
        XCTAssertEqual(result.seqSize, 1)
    }

    func testWindowRestartsWithoutSamplingWhenTimestampsDoNotAdvance() {
        let observations = (0 ... 30).map { block in (BlockNumber(block), BlockTime(1_000_000)) }

        let result = EstimatedBlockTime.initial.feed(observations)

        XCTAssertEqual(result.seqSize, 0)
        XCTAssertEqual(result.windowStartBlock, 30)
    }

    func testOldSamplesDoNotDominateAfterChainChangesBlockTime() {
        let legacyState = EstimatedBlockTime(blockTime: 6000, seqSize: 1000)
        let windows = 30
        let lastBlock = windows * Int(BlockTimeSampling.windowBlocks)
        let observations = (0 ... lastBlock).map { block in (BlockNumber(block), BlockTime(block) * 2000) }

        let result = legacyState.feed(observations)

        XCTAssertLessThan(result.blockTime, 2300, "expected average close to 2000")
        XCTAssertLessThanOrEqual(result.seqSize, BlockTimeSampling.maxSamplesMemory)
    }

    func testInitialStateHasNoWindow() {
        let initial = EstimatedBlockTime.initial

        XCTAssertEqual(initial.seqSize, 0)
        XCTAssertNil(initial.windowStartBlock)
        XCTAssertNil(initial.windowStartTime)
    }

    func testLegacyPersistedValueDecodesWithoutWindow() throws {
        let legacyJson = #"{"blockTime":6000,"seqSize":12}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(EstimatedBlockTime.self, from: legacyJson)

        XCTAssertEqual(decoded.blockTime, 6000)
        XCTAssertEqual(decoded.seqSize, 12)
        XCTAssertNil(decoded.windowStartBlock)
    }

    // MARK: - Prediction

    func testWithoutSamplesExpectedValueIsUsed() {
        let predicted = BlockTimeOperationFactory.predictBlockTime(
            estimated: .initial,
            expected: 2000,
            configured: nil
        )

        XCTAssertEqual(predicted, 2000)
    }

    func testFewSamplesAreBlendedWithExpected() {
        let predicted = BlockTimeOperationFactory.predictBlockTime(
            estimated: EstimatedBlockTime(blockTime: 6000, seqSize: 5),
            expected: 2000,
            configured: nil
        )

        XCTAssertEqual(predicted, 4000)
    }

    func testEnoughSamplesFullyReplaceExpectedWhenNoConfigPresent() {
        let predicted = BlockTimeOperationFactory.predictBlockTime(
            estimated: EstimatedBlockTime(blockTime: 6000, seqSize: 10),
            expected: 2000,
            configured: nil
        )

        XCTAssertEqual(predicted, 6000)
    }

    func testSamplesFarFromConfiguredBlockTimeAreIgnoredInFavourOfConfig() {
        let predicted = BlockTimeOperationFactory.predictBlockTime(
            estimated: EstimatedBlockTime(blockTime: 6000, seqSize: 10),
            expected: 2000,
            configured: 2000
        )

        XCTAssertEqual(predicted, 2000)
    }

    func testSamplesCloseToConfiguredBlockTimeRefineIt() {
        let predicted = BlockTimeOperationFactory.predictBlockTime(
            estimated: EstimatedBlockTime(blockTime: 2200, seqSize: 10),
            expected: 2000,
            configured: 2000
        )

        XCTAssertEqual(predicted, 2200)
    }

    func testSamplesMuchFasterThanConfiguredBlockTimeAreIgnoredToo() {
        let predicted = BlockTimeOperationFactory.predictBlockTime(
            estimated: EstimatedBlockTime(blockTime: 900, seqSize: 10),
            expected: 2000,
            configured: 2000
        )

        XCTAssertEqual(predicted, 2000)
    }
}

private extension EstimatedBlockTime {
    func feed(_ observations: [(BlockNumber, BlockTime)]) -> EstimatedBlockTime {
        observations.reduce(self) { state, observation in
            state.observing(block: observation.0, timestamp: observation.1)
        }
    }
}
