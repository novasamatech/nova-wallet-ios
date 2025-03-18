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

    struct CallDryRunEffects: Decodable {
        let executionResult: ExecutionResult
        let emittedEvents: [Event]
        let localXcm: Xcm.Message?
        let forwardedXcms: [ForwardedXcm]
    }

    typealias CallResult = Substrate.Result<CallDryRunEffects, JSON>
    typealias ExecutionResult = Substrate.Result<JSON, JSON>

    struct XcmDryRunEffects: Decodable {
        let executionResult: ExecutionResult
        let emittedEvents: [Event]
        let forwardedXcms: [ForwardedXcm]
    }

    typealias XcmResult = Substrate.Result<XcmDryRunEffects, JSON>
}
