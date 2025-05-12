import Foundation
import Operation_iOS

struct MultisigModel: Hashable {
    let accountId: AccountId
    let signatory: AccountId
    let otherSignatories: [AccountId]
    let threshold: Int
    let status: Status

    enum Status: String, CaseIterable {
        case new
        case active
        case revoked
    }
}

extension MultisigModel: Identifiable {
    var identifier: String {
        accountId.toHex()
    }
}

extension MultisigModel {
    func replacingStatus(_ newStatus: Status) -> MultisigModel {
        MultisigModel(
            accountId: accountId,
            signatory: signatory,
            otherSignatories: otherSignatories,
            threshold: threshold,
            status: newStatus
        )
    }
}
