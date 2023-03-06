import Foundation

struct GovernanceDelegateMetadataRemote: Codable, Equatable {
    let address: AccountAddress
    let name: String
    let image: URL
    let shortDescription: String
    let longDescription: String?
    let isOrganization: Bool
}
