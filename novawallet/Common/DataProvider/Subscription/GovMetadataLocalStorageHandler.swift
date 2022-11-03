import Foundation

protocol GovMetadataLocalStorageHandler: AnyObject {
    func handleGovMetadata(
        result: Result<ReferendumMetadataMapping?, Error>,
        chain: ChainModel
    )
}

extension GovMetadataLocalStorageHandler {
    func handleGovMetadata(
        result _: Result<ReferendumMetadataMapping?, Error>,
        chain _: ChainModel
    ) {}
}
