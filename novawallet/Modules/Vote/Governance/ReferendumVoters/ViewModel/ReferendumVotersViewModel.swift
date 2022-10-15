import Foundation

struct ReferendumVotersViewModel {
    let displayAddress: DisplayAddressViewModel
    let votes: String
    let preConviction: String
}

extension ReferendumVotersViewModel: Hashable {
    static func == (lhs: ReferendumVotersViewModel, rhs: ReferendumVotersViewModel) -> Bool {
        lhs.displayAddress.address == rhs.displayAddress.address
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(displayAddress.address)
    }
}
