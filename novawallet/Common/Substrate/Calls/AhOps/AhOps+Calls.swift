import Foundation
import SubstrateSdk

extension AhOpsPallet {
    struct WithdrawCrowdloanContributionCall: Codable {
        @StringCodable var blockNumber: BlockNumber
        @NullCodable var depositor: BytesCodable?
        @StringCodable var paraId: ParaId

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                path: CallCodingPath(
                    moduleName: AhOpsPallet.name,
                    callName: "withdraw_crowdloan_contribution"
                ),
                args: self
            )
        }
    }
}
