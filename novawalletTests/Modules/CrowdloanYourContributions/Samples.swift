import Foundation
import Foundation_iOS
import SubstrateSdk
import BigInt
@testable import novawallet

extension Crowdloan {
    static let currentBlockNumber: BlockNumber = 403_200 * 101

    static let ended = Crowdloan(
        paraId: 2001,
        fundInfo: CrowdloanFunds(
            depositor: Data(repeating: 1, count: 32),
            verifier: nil,
            deposit: 100,
            raised: 1000,
            end: 100,
            cap: 1000,
            lastContribution: .never,
            firstPeriod: 0,
            lastPeriod: 1,
            trieIndex: nil,
            fundIndex: StringScaleMapper(value: 2)
        )
    )

    static let active = Crowdloan(
        paraId: 2000,
        fundInfo: CrowdloanFunds(
            depositor: Data(repeating: 0, count: 32),
            verifier: nil,
            deposit: 100,
            raised: 100,
            end: currentBlockNumber + 100,
            cap: 1000,
            lastContribution: .never,
            firstPeriod: 100,
            lastPeriod: 101,
            trieIndex: nil,
            fundIndex: StringScaleMapper(value: 1)
        )
    )

    var fundIndex: UInt32 {
        fundInfo.fundIndex!.value
    }
}

extension ExternalContribution {
    static let sample = ExternalContribution(source: nil, amount: BigUInt(1_000_000), paraId: 2000)
}

extension CrowdloanContribution {
    static let sample = CrowdloanContribution(balance: 10_362_973, memo: Data())
}
