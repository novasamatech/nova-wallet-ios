enum TransferSetupRecipientAccount {
    case address(AccountAddress?)
    case external(ExternalAccount)

    struct ExternalAccount {
        var name: String
        var recipient: LoadableViewModelState<ExternalAccountValue?>
    }

    struct ExternalAccountValue {
        let address: AccountAddress
        let description: String?

        var displayTitle: String? {
            let displayDetails = description ?? ""

            if !displayDetails.isEmpty {
                return "\(address.truncated) (\(displayDetails))"
            } else {
                return address.truncated
            }
        }
    }

    var address: AccountAddress? {
        switch self {
        case let .address(address):
            return address
        case let .external(external):
            return external.recipient.value??.address
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
