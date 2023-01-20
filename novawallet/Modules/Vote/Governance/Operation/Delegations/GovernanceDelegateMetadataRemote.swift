import Foundation

struct GovernanceDelegateMetadataRemote: Decodable {
    let address: AccountAddress
    let name: String
    let image: URL
    let shortDescription: String
    let longDescription: String?
    let isOrganization: Bool
}
