import UIKit

final class AddDelegationInteractor {
    weak var presenter: AddDelegationInteractorOutputProtocol!
}

extension AddDelegationInteractor: AddDelegationInteractorInputProtocol {}

struct DelegateMetadataRemote{
    let address: String
    let name: String
    let image: URL?
    let shortDescription: String
    let longDescription: String?
    let isOrganization: Bool
}

struct OffChainDelegateMetadata {
    let accountId: AccountId
    let shortDescription: String
    let longDescription: String?
    let profileImageUrl: String?
    let isOrganization: Bool
    let name: String
}
