enum TransferSetupRecipientAccount {
    case address(AccountAddress?)
    case external(ExternalAccount)

    struct ExternalAccount {
        var name: String
        var address: LoadableViewModelState<AccountAddress?>
    }

    var address: AccountAddress? {
        switch self {
        case let .address(address):
            return address
        case let .external(external):
            return external.address.value ?? nil
        }
    }

    var isExternal: Bool {
        switch self {
        case .address:
            return false
        case .external:
            return true
        }
    }

    var name: String? {
        switch self {
        case .address:
            return nil
        case let .external(external):
            return external.name
        }
    }
}
