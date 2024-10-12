import Foundation
import web3swift
import Web3Core

protocol EvmSubscriptionMessageFactoryProtocol: AnyObject {
    func erc20(
        for holder: AccountAddress,
        contracts: Set<AccountAddress>
    ) throws -> EvmSubscriptionMessage.ERC20Transfer
}

enum EvmSubscriptionMessageFactoryError: Error {
    case trasferEventNotFound
    case invalidAddress(_ address: AccountAddress)
}

final class EvmSubscriptionMessageFactory: EvmSubscriptionMessageFactoryProtocol {
    func erc20(
        for holder: AccountAddress,
        contracts: Set<AccountAddress>
    ) throws -> EvmSubscriptionMessage.ERC20Transfer {
        let erc20Abi = try EthereumContract(Web3.Utils.erc20ABI)

        guard let event = erc20Abi.events[ERC20TransferEvent.name] else {
            throw EvmSubscriptionMessageFactoryError.trasferEventNotFound
        }

        let eventTopic = event.topic

        guard
            let addressTopic = ABIEncoder.encodeSingleType(
                type: .address,
                value: holder as NSString
            ) else {
            throw EvmSubscriptionMessageFactoryError.invalidAddress(holder)
        }

        let incomingFilter = EvmSubscriptionMessage.LogsParams(
            logs: .init(
                address: Array(contracts),
                topics: [
                    .single(eventTopic),
                    .anyValue,
                    .single(addressTopic)
                ]
            )
        )

        let outgoingFilter = EvmSubscriptionMessage.LogsParams(
            logs: .init(
                address: Array(contracts),
                topics: [
                    .single(eventTopic),
                    .single(addressTopic),
                    .anyValue
                ]
            )
        )

        return .init(incomingFilter: incomingFilter, outgoingFilter: outgoingFilter)
    }
}
