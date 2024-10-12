import Foundation
import BigInt
import Web3Core

struct ERC20TransferEvent {
    static let tokenType = "ERC20"
    static let name = "Transfer"

    let sender: AccountAddress
    let receiver: AccountAddress
    let amount: BigUInt
}

final class EvmEventParser {
    func parseERC20Transfer(from event: EventLog) -> ERC20TransferEvent? {
        guard event.topics.count > 2 else {
            return nil
        }

        let (optSender, _) = ABIDecoder.decodeSingleType(type: .address, data: event.topics[1])
        let (optReceiver, _) = ABIDecoder.decodeSingleType(type: .address, data: event.topics[2])
        let (optAmount, _) = ABIDecoder.decodeSingleType(type: .uint(bits: 256), data: event.data)

        guard
            let sender = try? (optSender as? EthereumAddress)?.addressData.toAddress(using: .ethereum),
            let receiver = try? (optReceiver as? EthereumAddress)?.addressData.toAddress(using: .ethereum),
            let amount = optAmount as? BigUInt else {
            return nil
        }

        return .init(sender: sender, receiver: receiver, amount: amount)
    }
}
