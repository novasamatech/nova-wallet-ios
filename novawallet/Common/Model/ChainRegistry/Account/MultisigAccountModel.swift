import Foundation
import Operation_iOS

struct MultisigAccountModel: Hashable {
    let signatory: AccountId
    let signatories: [AccountId]
    let threshold: Int
    let callHash: String
    let timepoint: Timepoint
    let status: Status

    enum Status: String, CaseIterable {
        case pending
        case approved
        case rejected
    }

    struct Timepoint: Codable, Hashable {
        /// The height of the chain at the point in time.
        let height: BlockNumber
        /// The index of the extrinsic at the point in time.
        let index: UInt32
    }
}

extension MultisigAccountModel: Identifiable {
    var identifier: String {
        [
            signatory.toHex(),
            signatories.map { $0.toHex() }.joined(with: .dash),
            callHash,
            "\(timepoint.height)",
            "\(timepoint.index)"
        ].joined(with: .dash)
    }
}
