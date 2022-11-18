import Foundation
import web3swift
import Core

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
    static let erc20Transfer = "Transfer"

    func erc20(
        for holder: AccountAddress,
        contracts: Set<AccountAddress>
    ) throws -> EvmSubscriptionMessage.ERC20Transfer {
        let erc20Abi = try EthereumContract(Web3.Utils.erc20ABI)

        guard let event = erc20Abi.events[Self.erc20Transfer] else {
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

        let incomingFilter = EvmSubscriptionMessage.Params(
            logs: .init(
                address: Array(contracts),
                topics: [
                    .single(eventTopic),
                    .anyValue,
                    .single(addressTopic)
                ]
            )
        )

        let outgoingFilter = EvmSubscriptionMessage.Params(
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
