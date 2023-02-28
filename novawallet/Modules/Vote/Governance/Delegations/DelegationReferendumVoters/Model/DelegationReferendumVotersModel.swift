enum DelegationReferendumVotersModel: Hashable {
    case grouped(GroupSection)
    case single(SingleSection)

    var address: AccountAddress {
        switch self {
        case let .grouped(model):
            return model.model.delegateInfo.addressViewModel.address
        case let .single(model):
            return model.model.delegateInfo.addressViewModel.address
        }
    }
}

extension DelegationReferendumVotersModel {
    struct GroupSection: Hashable {
        let id: String
        let model: DelegateGroupVotesHeader.Model
        let cells: [DelegateSingleVoteCollectionViewCell.Model]

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: GroupSection, rhs: GroupSection) -> Bool {
            lhs.id == rhs.id && lhs.model == rhs.model && lhs.cells == rhs.cells
        }
    }

    struct SingleSection: Hashable {
        static func == (lhs: SingleSection, rhs: SingleSection) -> Bool {
            lhs.id == rhs.id && lhs.model == rhs.model
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        let id: String
        let model: DelegateSingleVoteHeader.Model
    }
}
