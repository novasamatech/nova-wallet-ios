import Foundation
import RobinHood

protocol GovMetadataLocalStorageHandler: AnyObject {
    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        chain: ChainModel
    )

    func handleGovernanceMetadataDetails(
        result: Result<ReferendumMetadataLocal?, Error>,
        chain: ChainModel,
        referendumId: ReferendumIdLocal
    )
}

extension GovMetadataLocalStorageHandler {
    func handleGovernanceMetadataPreview(
        result _: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        chain _: ChainModel
    ) {}

    func handleGovernanceMetadataDetails(
        result _: Result<ReferendumMetadataLocal?, Error>,
        chain _: ChainModel,
        referendumId _: ReferendumIdLocal
    ) {}
}
