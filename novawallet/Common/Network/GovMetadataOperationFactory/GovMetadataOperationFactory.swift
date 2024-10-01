import Foundation
import Operation_iOS
import SubstrateSdk

protocol GovMetadataOperationFactoryProtocol {
    func createPreviewsOperation(for parameters: JSON?) -> BaseOperation<[ReferendumMetadataPreview]>

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal,
        parameters: JSON?
    ) -> BaseOperation<ReferendumMetadataLocal?>
}

protocol OpenGovSummaryOperationFactoryProtocol {
    func createSummaryOperation(for referendumId: ReferendumIdLocal) -> BaseOperation<ReferendumSummary?>
}

struct ReferendumSummary: Decodable {
    let summary: String
}
