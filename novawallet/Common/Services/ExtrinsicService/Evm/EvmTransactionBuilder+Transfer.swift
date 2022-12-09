import Foundation
import BigInt
import web3swift
import Core

extension EvmTransactionBuilderProtocol {
    func erc20Transfer(
        to recepient: AccountAddress,
        contract: AccountAddress,
        amount: BigUInt
    ) throws -> EvmTransactionBuilderProtocol {
        guard
            let contractAddress = EthereumAddress(contract),
            let recepientAddress = EthereumAddress(recepient) else {
            throw AccountAddressConversionError.invalidEthereumAddress
        }

        let evmContract = try EthereumContract(Web3Utils.erc20ABI, at: contractAddress)

        guard let data = evmContract.method(
            "transfer",
            parameters: [recepientAddress, amount] as [AnyObject],
            extraData: Data()
        ) else {
            throw EvmTransactionBuilderError.invalidDataParameters
        }

        return toAddress(contract).usingTransactionData(data)
    }
}
