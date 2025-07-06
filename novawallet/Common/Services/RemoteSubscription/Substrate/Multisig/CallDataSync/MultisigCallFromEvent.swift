import Foundation

struct MultisigCallFromEvent {
    let callOrHash: MultisigCallOrHash
    let timepoint: MultisigPallet.EventTimePoint
    let blockNumber: BlockNumber
    let extrinsicIndex: ExtrinsicIndex
}
