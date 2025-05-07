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
    let accountId: AccountId
    let signatories: [AccountId]
    let threshold: Int

    func otherSignatories(than signatory: AccountId) -> [AccountId] {
        signatories.filter { $0 != signatory }
    }
}
