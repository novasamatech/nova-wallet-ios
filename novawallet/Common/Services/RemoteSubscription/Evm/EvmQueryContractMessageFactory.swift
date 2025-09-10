import Foundation
import web3swift
import Web3Core

protocol EvmQueryContractMessageFactoryProtocol: AnyObject {
    func erc20Balance(of holder: AccountAddress, contractAddress: AccountAddress) throws -> EthereumTransaction
    func erc20Name(from contractAddress: AccountAddress) throws -> EthereumTransaction
    func erc20Symbol(from contractAddress: AccountAddress) throws -> EthereumTransaction
    func erc20Decimals(from contractAddress: AccountAddress) throws -> EthereumTransaction
    func erc20TotalSupply(from contractAddress: AccountAddress) throws -> EthereumTransaction
}

enum EvmQueryContractMessageFactoryError: Error {
    case dataEncodingFailed
}

final class EvmQueryContractMessageFactory: EvmQueryContractMessageFactoryProtocol {
    static let erc20Balance = "balanceOf"
    static let erc20Name = "name"
    static let erc20Symbol = "symbol"
    static let erc20Decimals = "decimals"
    static let totalSupply = "totalSupply"

    func erc20Balance(of holder: AccountAddress, contractAddress: AccountAddress) throws -> EthereumTransaction {
        let contract = try EthereumContract(Web3.Utils.erc20ABI)

        let data = contract.method(Self.erc20Balance, parameters: [holder as NSString], extraData: Data())

        return try createContractQuery(
            data: data,
            contractAddress: contractAddress,
            holder: holder
        )
    }

    func erc20Name(from contractAddress: AccountAddress) throws -> EthereumTransaction {
        try createConstantQuery(from: contractAddress, name: Self.erc20Name)
    }

    func erc20Symbol(from contractAddress: AccountAddress) throws -> EthereumTransaction {
        try createConstantQuery(from: contractAddress, name: Self.erc20Symbol)
    }

    func erc20Decimals(from contractAddress: AccountAddress) throws -> EthereumTransaction {
        try createConstantQuery(from: contractAddress, name: Self.erc20Decimals)
    }

    func erc20TotalSupply(from contractAddress: AccountAddress) throws -> EthereumTransaction {
        try createConstantQuery(from: contractAddress, name: Self.totalSupply)
    }

    private func createConstantQuery(from contractAddress: AccountAddress, name: String) throws -> EthereumTransaction {
        let contract = try EthereumContract(Web3.Utils.erc20ABI)
        let data = contract.method(name, parameters: [], extraData: Data())

        return try createContractQuery(data: data, contractAddress: contractAddress, holder: nil)
    }

    private func createContractQuery(
        data: Data?,
        contractAddress: AccountAddress,
        holder: AccountAddress?
    ) throws -> EthereumTransaction {
        guard let data = data else {
            throw EvmQueryContractMessageFactoryError.dataEncodingFailed
        }

        let actualHolder = holder ?? AccountId.nonzeroAccountId(
            of: ChainModel.getAccountIdSize(for: .ethereum)
        ).toHex(includePrefix: true)

        return .init(
            from: actualHolder,
            to: contractAddress,
            gas: nil,
            gasPrice: nil,
            value: nil,
            data: data.toHex(includePrefix: true),
            nonce: nil
        )
    }
}
