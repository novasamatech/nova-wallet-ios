import Foundation
import SubstrateSdk
import RobinHood

final class GovV2SubsquareOperationFactory: BaseSubsquareOperationFactory {
    override func createPreviewUrl(from _: JSON?) -> URL {
        let url = baseUrl.appendingPathComponent("gov2/referendums")

        return appendingPageSize(to: url)
    }

    override func createDetailsUrl(from referendumId: ReferendumIdLocal, parameters _: JSON?) -> URL {
        baseUrl.appendingPathComponent("gov2/referendums/\(referendumId)")
    }
}
