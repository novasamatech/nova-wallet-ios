import Foundation
import SubstrateSdk

enum SubqueryMultisigs {
    struct MultisigsResponseQueryWrapper<T: Decodable>: Decodable {
        let query: T
    }

    // MARK: - Find Multisigs

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

    // MARK: - Fetch Call Data

    struct FetchMultisigCallDataResponse: Decodable {
        let multisigOperations: SubqueryNodes<OffChainMultisigOperationInfo>
    }

    struct OffChainMultisigOperationInfo: Decodable {
        @HexCodable var callHash: Substrate.CallHash
        @OptionHexCodable var callData: Substrate.CallData?
        let timestamp: Int
        let events: SubqueryNodes<OperationEvent>
    }

    struct OperationEvent: Decodable {
        let timestamp: Int
    }
}

struct OffChainMultisigInfo {
    let callHash: Substrate.CallHash
    let callData: Substrate.CallData?
    let timestamp: Int
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
