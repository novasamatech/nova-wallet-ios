import Foundation

extension CallCodingPath {
    static var erc20Tranfer: CallCodingPath {
        CallCodingPath(
            moduleName: ERC20TransferEvent.tokenType,
            callName: ERC20TransferEvent.name
        )
    }

    var isERC20Transfer: Bool {
        moduleName == ERC20TransferEvent.tokenType && callName == ERC20TransferEvent.name
    }

    static var evmNativeTransfer: CallCodingPath {
        CallCodingPath(moduleName: "EvmNative", callName: "Transfer")
    }

    static var evmNativeTransaction: CallCodingPath {
        CallCodingPath(moduleName: "EvmNative", callName: "Transaction")
    }

    var isEvmNativeTransfer: Bool {
        let transfer = Self.evmNativeTransfer

        return moduleName == transfer.moduleName && callName == transfer.callName
    }

    var isEvmNativeTransaction: Bool {
        let transaction = Self.evmNativeTransaction

        return moduleName == transaction.moduleName && callName == transaction.callName
    }
}
