import Foundation
import SubstrateSdk
import RobinHood

final class GovV1SubsquareOperationFactory: BaseSubsquareOperationFactory {
    override func createPreviewUrl(from _: JSON?) -> URL {
        let url = baseUrl.appendingPathComponent("democracy/referendums")
        return appendingPageSize(to: url)
    }

    override func createDetailsUrl(from referendumId: ReferendumIdLocal, parameters _: JSON?) -> URL {
        baseUrl.appendingPathComponent("democracy/referendums/\(referendumId)")
    }
}
