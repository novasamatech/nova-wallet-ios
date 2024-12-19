import Foundation
import SubstrateSdk

struct SubstrateBlockDetails {
    let extrinsicsWithEvents: SubstrateExtrinsicsEvents
    let inherentsEvents: SubstrateInherentsEvents
}

struct SubstrateExtrinsicEvents {
    let extrinsicHash: Data
    let extrinsicData: Data
    let eventRecords: [EventRecord]
}

typealias SubstrateExtrinsicsEvents = [SubstrateExtrinsicEvents]

struct SubstrateInherentsEvents {
    let initialization: [Event]
    let finalization: [Event]
}
