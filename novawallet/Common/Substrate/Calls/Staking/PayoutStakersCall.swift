import Foundation
import SubstrateSdk

extension Staking {
    enum PayoutCall {
        struct V1: Codable {
            enum CodingKeys: String, CodingKey {
                case validatorStash = "validator_stash"
                case era
            }

            let validatorStash: Data
            @StringCodable var era: EraIndex

            static func getCallPath(by stakingModule: String) -> CallCodingPath {
                CallCodingPath(moduleName: stakingModule, callName: "payout_stakers")
            }

            func runtimeCall() -> RuntimeCall<Self> {
                let callPath = Self.getCallPath(by: Staking.module)

                return RuntimeCall(
                    moduleName: callPath.moduleName,
                    callName: callPath.callName,
                    args: self
                )
            }
        }

        struct V2: Codable {
            enum CodingKeys: String, CodingKey {
                case validatorStash = "validator_stash"
                case era
                case page
            }

            let validatorStash: Data
            @StringCodable var era: EraIndex
            @StringCodable var page: Staking.ValidatorPage

            static func getCallPath(by stakingModule: String) -> CallCodingPath {
                CallCodingPath(moduleName: stakingModule, callName: "payout_stakers_by_page")
            }

            func runtimeCall() -> RuntimeCall<Self> {
                let callPath = Self.getCallPath(by: Staking.module)

                return RuntimeCall(
                    moduleName: callPath.moduleName,
                    callName: callPath.callName,
                    args: self
                )
            }
        }

        static func appendingCall(
            for validatorStash: AccountId,
            era: EraIndex,
            pages: Set<Staking.ValidatorPage>,
            codingFactory: RuntimeCoderFactoryProtocol,
            builder: ExtrinsicSplitting
        ) throws -> ExtrinsicSplitting {
            let v2CallPath = V2.getCallPath(by: Staking.module)

            if codingFactory.hasCall(for: v2CallPath) {
                return pages.reduce(builder) { accum, page in
                    let call = V2(validatorStash: validatorStash, era: era, page: page).runtimeCall()
                    return accum.adding(call: call)
                }
            } else {
                let call = V1(validatorStash: validatorStash, era: era).runtimeCall()
                return builder.adding(call: call)
            }
        }
    }
}
