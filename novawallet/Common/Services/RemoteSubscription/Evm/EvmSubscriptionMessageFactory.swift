import Foundation
import web3swift

protocol EvmSubscriptionMessageFactoryProtocol: AnyObject {
    func erc20(for holder: AccountAddress, contracts: Set<AccountAddress>) -> EvmSubscriptionMessage.Logs
}

final class EvmSubscriptionMessageFactory {

}

extension EvmSubscriptionMessageFactory: EvmSubscriptionMessageFactoryProtocol {
    func erc20(for holder: AccountAddress, contracts: Set<AccountAddress>) -> EvmSubscriptionMessage.Logs {
        
    }
}
