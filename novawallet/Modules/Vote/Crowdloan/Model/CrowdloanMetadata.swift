import Foundation

struct CrowdloanMetadata {
    let blockNumber: BlockNumber
    let blockDuration: BlockTime
    let leasingPeriod: LeasingPeriod
    let leasingOffset: LeasingOffset

    var leasingPeriodIndex: LeasingPeriod {
        guard blockNumber >= leasingOffset, leasingPeriod > 0 else {
            return 0
        }

        return (blockNumber - leasingOffset) / leasingPeriod
    }

    func firstBlockNumber(of leasingPeriodIndex: LeasingPeriod) -> BlockNumber {
        leasingPeriodIndex * leasingPeriod + leasingOffset
    }
}
