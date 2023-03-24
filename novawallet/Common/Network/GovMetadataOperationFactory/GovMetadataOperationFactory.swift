import Foundation
import RobinHood
import SubstrateSdk

protocol GovMetadataOperationFactoryProtocol {
    func createPreviewsOperation(for parameters: JSON?) -> BaseOperation<[ReferendumMetadataPreview]>

    func createDetailsOperation(
        for referendumId: ReferendumIdLocal,
        parameters: JSON?
    ) -> BaseOperation<ReferendumMetadataLocal?>
}
