import Foundation
import Operation_iOS

struct MultisigModel: Hashable {
    let accountId: AccountId
    let signatory: AccountId
    let otherSignatories: [AccountId]
    let threshold: Int
    let status: Status

    enum Status: String, CaseIterable {
        case pending
        case approved
        case rejected
    }
}

extension MultisigModel: Identifiable {
    var identifier: String {
        [
            accountId.toHex(),
            signatory.toHex(),
            otherSignatories.map { $0.toHex() }.joined(with: .dash)
        ].joined(with: .dash)
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
