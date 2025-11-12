import Foundation
import BigInt
import Operation_iOS

final class EvmTransferCommandFactory {
    /// Adds an EVM transfer command to the transaction builder based on the transfer type
    /// - Parameters:
    ///   - builder: The EVM transaction builder to add the command to
    ///   - amount: The amount to transfer
    ///   - recipient: The recipient's account address
    ///   - type: The type of transfer (native or ERC20)
    /// - Returns: A tuple containing the updated builder and the call coding path
    func addingTransferCommand(
        to builder: EvmTransactionBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountAddress,
        type: EvmTransferType
    ) throws -> (EvmTransactionBuilderProtocol, CallCodingPath?) {
        let amountValue = amount.value

        switch type {
        case .native:
            let newBuilder = try builder.nativeTransfer(to: recipient, amount: amountValue)
            return (newBuilder, CallCodingPath.evmNativeTransfer)

        case let .erc20(contract):
            let newBuilder = try builder.erc20Transfer(
                to: recipient,
                contract: contract,
                amount: amountValue
            )
            return (newBuilder, CallCodingPath.erc20Tranfer)
        }
    }
}
