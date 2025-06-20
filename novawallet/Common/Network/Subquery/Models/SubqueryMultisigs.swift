import Foundation

enum SubqueryMultisigs {
    struct FindMultisigsResponseQueryWrapper: Decodable {
        let query: FindMultisigsResponse
    }

    struct FindMultisigsResponse: Decodable {
        let accounts: SubqueryNodes<RemoteMultisig>
    }

    struct RemoteMultisig: Decodable {
        @HexCodable var id: AccountId
        let threshold: Int
        let signatories: SubqueryNodes<RemoteSignatoryWrapper>
    }

    struct RemoteSignatoryWrapper: Decodable {
        let signatory: RemoteSignatory
    }

    struct RemoteSignatory: Decodable {
        @HexCodable var id: AccountId
    }
}

struct DiscoveredMultisig: DiscoveredDelegatedAccountProtocol {
    var delegateAccountId: AccountId {
        signatory
    }

    let accountId: AccountId
    let signatory: AccountId
    let signatories: [AccountId]
    let threshold: Int

    func otherSignatories(than signatory: AccountId) -> [AccountId] {
        signatories.filter { $0 != signatory }
    }
}
