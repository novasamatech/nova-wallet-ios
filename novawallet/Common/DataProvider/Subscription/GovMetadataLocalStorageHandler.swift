import Foundation
import RobinHood

protocol GovMetadataLocalStorageHandler: AnyObject {
    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        option: GovernanceSelectedOption
    )

    func handleGovernanceMetadataDetails(
        result: Result<ReferendumMetadataLocal?, Error>,
        option: GovernanceSelectedOption,
        referendumId: ReferendumIdLocal
    )
}

extension GovMetadataLocalStorageHandler {
    func handleGovernanceMetadataPreview(
        result _: Result<[DataProviderChange<ReferendumMetadataLocal>], Error>,
        option _: GovernanceSelectedOption
    ) {}

    func handleGovernanceMetadataDetails(
        result _: Result<ReferendumMetadataLocal?, Error>,
        option _: GovernanceSelectedOption,
        referendumId _: ReferendumIdLocal
    ) {}
}
