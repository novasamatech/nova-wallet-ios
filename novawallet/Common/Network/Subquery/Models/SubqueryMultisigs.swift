import Foundation

enum SubqueryMultisigs {
    struct FindMultisigsResponse: Decodable {
        let accounts: SubqueryNodes<RemoteMultisig>
    }
    
    struct RemoteMultisig: Decodable {
        let id: AccountId
        let threshold: Int
        let signatories: SubqueryNodes<RemoteSignatoryWrapper>
    }
    
    struct RemoteSignatoryWrapper: Decodable {
        let signatory: RemoteSignatory
    }
    
    struct RemoteSignatory: Decodable {
        let id: AccountId
    }
}

struct DiscoveredMultisig {
    let signatory: AccountId
    let signatories: [AccountId]
    let threshold: Int
}
