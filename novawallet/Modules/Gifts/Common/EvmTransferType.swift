enum EvmTransferType {
    case native
    case erc20(AccountAddress)

    var transactionSource: TransactionHistoryItemSource {
        switch self {
        case .native:
            return .evmNative
        case .erc20:
            return .evmAsset
        }
    }
}
