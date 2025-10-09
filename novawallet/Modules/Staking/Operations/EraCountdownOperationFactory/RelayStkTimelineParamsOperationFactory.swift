import Foundation
import Operation_iOS

struct RelayStkTimelineParams {
    let sessionLength: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentEpochIndex: EpochIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let eraDelayInBlocks: UInt32
    let blockTime: Moment
}

protocol RelayStkTimelineParamsOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<RelayStkTimelineParams>
}

enum RelayStkTimelineAsync {
    static let eraDelay: UInt32 = 2

    static func delay(for chain: ChainModel) -> UInt32 {
        chain.separateTimelineChain ? Self.eraDelay : 0
    }
}
