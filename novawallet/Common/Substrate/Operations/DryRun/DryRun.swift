import Foundation
import SubstrateSdk

enum DryRun {
    static let apiName = "DryRunApi"

    struct ForwardedXcm: Decodable {
        let location: Xcm.VersionedMultilocation
        let messages: [Xcm.Message]

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            location = try container.decode(Xcm.VersionedMultilocation.self)
            messages = try container.decode([Xcm.Message].self)
        }
    }

    typealias CallExecutionResult = Substrate.Result<JSON, JSON>

    struct CallDryRunEffects: Decodable {
        let executionResult: CallExecutionResult
        let emittedEvents: [Event]
        let localXcm: Xcm.Message?
        let forwardedXcms: [ForwardedXcm]
    }

    typealias CallResult = Substrate.Result<CallDryRunEffects, JSON>

    typealias XcmExecutionResult = Xcm.Outcome<BlockchainWeight.WeightV2, JSON>

    struct XcmDryRunEffects: Decodable {
        let executionResult: XcmExecutionResult
        let emittedEvents: [Event]
        let forwardedXcms: [ForwardedXcm]
    }

    typealias XcmResult = Substrate.Result<XcmDryRunEffects, JSON>
}
