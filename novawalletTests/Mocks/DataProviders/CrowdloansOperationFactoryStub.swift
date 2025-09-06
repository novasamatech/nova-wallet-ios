import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class CrowdloansOperationFactoryStub: CrowdloanOperationFactoryProtocol {
    let crowdloans: [Crowdloan]
    let parachainLeaseInfo: [ParachainLeaseInfo]

    init(crowdloans: [Crowdloan], parachainLeaseInfo: [ParachainLeaseInfo]) {
        self.crowdloans = crowdloans
        self.parachainLeaseInfo = parachainLeaseInfo
    }

    func fetchCrowdloansOperation(
        connection _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        CompoundOperationWrapper.createWithResult(crowdloans)
    }

    func fetchContributionOperation(
        connection _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        accountId: AccountId,
        index: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        CompoundOperationWrapper.createWithResult(
            CrowdloanContributionResponse(accountId: accountId, index: index, contribution: nil)
        )
    }

    func fetchLeaseInfoOperation(
        connection _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        params _: [LeaseParam]
    ) -> CompoundOperationWrapper<[ParachainLeaseInfo]> {
        CompoundOperationWrapper.createWithResult(parachainLeaseInfo)
    }
}
