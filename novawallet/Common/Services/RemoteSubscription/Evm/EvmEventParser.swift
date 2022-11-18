import Foundation
import BigInt
import Core

struct ERC20TransferEvent {
    let sender: AccountId
    let receiver: AccountId
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
            let sender = (optSender as? EthereumAddress)?.addressData,
            let receiver = (optReceiver as? EthereumAddress)?.addressData,
            let amount = optAmount as? BigUInt else {
            return nil
        }

        return .init(sender: sender, receiver: receiver, amount: amount)
    }
}
