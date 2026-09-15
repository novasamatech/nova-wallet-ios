import Foundation

enum BlockTimeSampling {
    /// Minimum number of blocks a sampling window must span before it produces a block time sample.
    ///
    /// Block time is measured as `timestamp span / block span` over a window instead of the delta between two
    /// consecutive blocks. Chains with elastic scaling (Hydration, Asset Hub) produce several blocks per relay slot
    /// that share the same timestamp, so consecutive deltas look like `0, 0, 6000` and cannot be averaged reliably.
    /// Spanning many slots also tolerates skipped block notifications.
    static let windowBlocks: BlockNumber = 30

    /// How many completed windows the running average remembers. Bounding the memory lets the estimate follow
    /// a runtime upgrade that changes the block time instead of being pinned to samples collected months ago.
    static let maxSamplesMemory: Int = 10
}

extension EstimatedBlockTime {
    static var initial: EstimatedBlockTime {
        EstimatedBlockTime(blockTime: 0, seqSize: 0)
    }

    /// Folds a new `(block, timestamp)` observation into the sampling state.
    ///
    /// A window is opened at the first observation and closed once it spans at least
    /// ``BlockTimeSampling/windowBlocks`` blocks, producing one sample. Non-monotonic observations
    /// (reorg, node switch, timestamps not advancing) restart the window.
    func observing(block: BlockNumber, timestamp: BlockTime) -> EstimatedBlockTime {
        guard
            let startBlock = windowStartBlock,
            let startTime = windowStartTime,
            block > startBlock,
            timestamp >= startTime else {
            return restartingWindow(block: block, timestamp: timestamp)
        }

        let blockSpan = block - startBlock

        guard blockSpan >= BlockTimeSampling.windowBlocks else {
            return self
        }

        let timeSpan = timestamp - startTime

        guard timeSpan > 0 else {
            return restartingWindow(block: block, timestamp: timestamp)
        }

        let sample = timeSpan / BlockTime(blockSpan)
        let rememberedSamples = min(seqSize, BlockTimeSampling.maxSamplesMemory)
        let newBlockTime = (blockTime * BlockTime(rememberedSamples) + sample) / BlockTime(rememberedSamples + 1)

        return EstimatedBlockTime(
            blockTime: newBlockTime,
            seqSize: min(seqSize + 1, BlockTimeSampling.maxSamplesMemory),
            windowStartBlock: block,
            windowStartTime: timestamp
        )
    }

    private func restartingWindow(block: BlockNumber, timestamp: BlockTime) -> EstimatedBlockTime {
        EstimatedBlockTime(
            blockTime: blockTime,
            seqSize: seqSize,
            windowStartBlock: block,
            windowStartTime: timestamp
        )
    }
}
