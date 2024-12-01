import Foundation

struct SubstrateExtrinsicEvents {
    let extrinsicHash: Data
    let events: [Event]
}

typealias SubstrateExtrinsicsEvents = [SubstrateExtrinsicEvents]

struct SubstrateInherentsEvents {
    let initialization: [Event]
    let finalization: [Event]
}
