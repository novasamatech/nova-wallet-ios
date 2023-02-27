struct VotesViewModel: Hashable {
    static func == (lhs: VotesViewModel, rhs: VotesViewModel) -> Bool {
        lhs.displayAddress.address == rhs.displayAddress.address
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(displayAddress.address)
    }

    let displayAddress: DisplayAddressViewModel
    let votes: String
    let votesDetails: String
}
