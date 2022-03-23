import Foundation
@testable import novawallet
import RobinHood
import SubstrateSdk

final class CrowdloansOperationFactoryStub: CrowdloanOperationFactoryProtocol {
    let crowdloans: [Crowdloan]
    let parachainLeaseInfo: [ParachainLeaseInfo]

    init(crowdloans: [Crowdloan], parachainLeaseInfo: [ParachainLeaseInfo]) {
        self.crowdloans = crowdloans
        self.parachainLeaseInfo = parachainLeaseInfo
    }

    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        CompoundOperationWrapper.createWithResult(crowdloans)
    }

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        accountId: AccountId,
        index: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        CompoundOperationWrapper.createWithResult(
            CrowdloanContributionResponse(accountId: accountId, index: index, contribution: nil)
        )
    }

    func fetchLeaseInfoOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        params: [LeaseParam]
    ) -> CompoundOperationWrapper<[ParachainLeaseInfo]> {
        CompoundOperationWrapper.createWithResult(parachainLeaseInfo)
    }
}
