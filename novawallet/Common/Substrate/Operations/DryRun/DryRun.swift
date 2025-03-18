import Foundation
import SubstrateSdk

enum DryRun {
    static let apiName = "DryRunApi"

    /*
     pub struct CallDryRunEffects<Event> {
         /// The result of executing the extrinsic.
         pub execution_result: DispatchResultWithPostInfo,
         /// The list of events fired by the extrinsic.
         pub emitted_events: Vec<Event>,
         /// The local XCM that was attempted to be executed, if any.
         pub local_xcm: Option<VersionedXcm<()>>,
         /// The list of XCMs that were queued for sending.
         pub forwarded_xcms: Vec<(VersionedLocation, Vec<VersionedXcm<()>>)>,
     }*/

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
        let forwardedXcms: [ForwardedXcm]
    }

    typealias CallResult = Substrate.Result<CallDryRunEffects, JSON>
    typealias ExecutionResult = Substrate.Result<JSON, JSON>
}
