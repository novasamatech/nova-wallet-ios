import Foundation
import Operation_iOS

struct RelayStkTimelineParams {
    let sessionLength: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentEpochIndex: EpochIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockTime: Moment
}

protocol RelayStkTimelineParamsOperationFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<RelayStkTimelineParams>
}
