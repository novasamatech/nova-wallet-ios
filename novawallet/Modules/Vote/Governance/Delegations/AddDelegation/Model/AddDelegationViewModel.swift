enum AddDelegationViewModel: Hashable {
    case yourDelegate(GovernanceYourDelegationCell.Model)
    case delegate(GovernanceDelegateTableViewCell.Model)

    var address: AccountAddress {
        switch self {
        case let .yourDelegate(model):
            return model.delegateViewModel.addressViewModel.address
        case let .delegate(model):
            return model.addressViewModel.address
        }
    }
}
