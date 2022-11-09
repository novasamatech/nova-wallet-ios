import Foundation

protocol GovMetadataLocalStorageHandler: AnyObject {
    func handleGovernanceMetadataPreview(
        result: Result<ReferendumMetadataMapping?, Error>,
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
        result _: Result<ReferendumMetadataMapping?, Error>,
        chain _: ChainModel
    ) {}

    func handleGovernanceMetadataDetails(
        result _: Result<ReferendumMetadataLocal?, Error>,
        chain _: ChainModel,
        referendumId _: ReferendumIdLocal
    ) {}
}
