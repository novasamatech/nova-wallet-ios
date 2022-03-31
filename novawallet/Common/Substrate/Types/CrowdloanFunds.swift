import Foundation
import SubstrateSdk
import BigInt

struct CrowdloanFunds: Codable, Equatable {
    let depositor: Data
    @NullCodable var verifier: MultiSigner?
    @StringCodable var deposit: BigUInt
    @StringCodable var raised: BigUInt
    @StringCodable var end: UInt32
    @StringCodable var cap: BigUInt
    let lastContribution: CrowdloanLastContribution
    @StringCodable var firstPeriod: UInt32
    @StringCodable var lastPeriod: UInt32

    // trieIndex was renamed to fundIndex in 9180
    // but we need to keep backward compatability
    let trieIndex: StringScaleMapper<UInt32>?
    let fundIndex: StringScaleMapper<FundIndex>?

    var index: FundIndex {
        if let fundIndex = fundIndex {
            return fundIndex.value
        }

        if let trieIndex = trieIndex {
            return trieIndex.value
        }

        fatalError("Either fundIndex or trieIndex must be provided")
    }

    func getBidderKey(for paraId: ParaId) -> BidderKey {
        fundIndex?.value ?? paraId
    }
}
