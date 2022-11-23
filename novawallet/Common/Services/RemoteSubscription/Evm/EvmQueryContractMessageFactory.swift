import Foundation
import web3swift
import Core

protocol EvmQueryContractMessageFactoryProtocol: AnyObject {
    func erc20Balance(of holder: AccountAddress, contractAddress: AccountAddress) throws -> EthereumTransaction
}

enum EvmQueryContractMessageFactoryError: Error {
    case balanceOfEncodingFailed
}

final class EvmQueryContractMessageFactory: EvmQueryContractMessageFactoryProtocol {
    static let erc20Balance = "balanceOf"

    func erc20Balance(of holder: AccountAddress, contractAddress: AccountAddress) throws -> EthereumTransaction {
        let contract = try EthereumContract(Web3.Utils.erc20ABI)

        guard let data = contract.method(Self.erc20Balance, parameters: [holder as NSString], extraData: Data()) else {
            throw EvmQueryContractMessageFactoryError.balanceOfEncodingFailed
        }

        return .init(
            from: holder,
            to: contractAddress,
            gas: nil,
            gasPrice: nil,
            value: nil,
            data: data.toHex(includePrefix: true),
            nonce: nil
        )
    }
}
