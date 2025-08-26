import Foundation
import SubstrateSdk

enum DryRun {
    static let apiName = "DryRunApi"

    struct ForwardedXcm: Decodable {
        let location: XcmUni.VersionedLocation
        let messages: [XcmUni.VersionedMessage]

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            location = try container.decode(XcmUni.VersionedLocation.self)
            messages = try container.decode([XcmUni.VersionedMessage].self)
        }
    }

    typealias CallExecutionResult = Substrate.Result<JSON, JSON>

    struct CallDryRunEffects: Decodable {
        let executionResult: CallExecutionResult
        let emittedEvents: [Event]
        let localXcm: XcmUni.VersionedMessage?
        let forwardedXcms: [ForwardedXcm]
    }

    typealias CallResult = Substrate.Result<CallDryRunEffects, JSON>

    enum DryRunError<R>: Error {
        case failure(JSON)
        case execution(JSON)
    }

    typealias CallDryRunError = DryRunError<JSON>

    typealias XcmExecutionResult = Xcm.Outcome<Substrate.WeightV2, JSON>

    struct XcmDryRunEffects: Decodable {
        let executionResult: XcmExecutionResult
        let emittedEvents: [Event]
        let forwardedXcms: [ForwardedXcm]
    }

    typealias XcmResult = Substrate.Result<XcmDryRunEffects, JSON>

    typealias XcmDryRunError = DryRunError<JSON>
}

extension DryRun.CallResult {
    func ensureSuccessExecution() throws -> DryRun.CallDryRunEffects {
        let effects = try ensureOkOrError { DryRun.CallDryRunError.failure($0) }

        try effects.executionResult.ensureOkOrError { DryRun.CallDryRunError.execution($0) }

        return effects
    }
}

extension DryRun.CallDryRunEffects {
    func xcmVersion() -> Xcm.Version? {
        forwardedXcms.first?.location.version
    }
}

extension DryRun.XcmResult {
    func ensureSuccessExecution() throws -> DryRun.XcmDryRunEffects {
        let effects = try ensureOkOrError { DryRun.XcmDryRunError.failure($0) }

        try effects.executionResult.ensureCompleteOrError { DryRun.XcmDryRunError.execution($0) }

        return effects
    }
}
