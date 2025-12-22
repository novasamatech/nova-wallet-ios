import Foundation
import SubstrateSdk

extension AhOpsPallet {
    struct WithdrawCrowdloanContributionCall: Codable {
        enum CodingKeys: String, CodingKey {
            case block
            case depositor
            case paraId = "para_id"
        }

        @StringCodable var block: BlockNumber
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
