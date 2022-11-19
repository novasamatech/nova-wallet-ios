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
}
