import BigInt
import Foundation
import Operation_iOS
import SubstrateSdk
import Web3Core
import web3swift

extension HydraAave.Contract {
    static func createCallOperation(
        connection: JSONRPCEngine,
        contract: String,
        data: String,
        timeout: Int = 10
    ) -> BaseOperation<String> {
        let transaction = EthereumTransaction(
            from: AccountId.nonzeroAccountId(of: 20).toHex(includePrefix: true),
            to: contract,
            gas: nil,
            gasPrice: nil,
            value: nil,
            data: data,
            nonce: nil
        )

        let params = EvmQueryMessage.Params(call: transaction, block: .latest)

        return JSONRPCOperation<EvmQueryMessage.Params, String>(
            engine: connection,
            method: EvmQueryMessage.method,
            parameters: params,
            timeout: timeout
        )
    }

    static func getUserAccountDataCall(user: AccountId) throws -> String {
        try encodeCall(method: getUserAccountDataMethod, parameters: [ethereumAddress(user)])
    }

    static func getUserConfigurationCall(user: AccountId) throws -> String {
        try encodeCall(method: getUserConfigurationMethod, parameters: [ethereumAddress(user)])
    }

    static func getUserEModeCall(user: AccountId) throws -> String {
        try encodeCall(method: getUserEModeMethod, parameters: [ethereumAddress(user)])
    }

    static func getEModeCategoryDataCall(categoryId: BigUInt) throws -> String {
        try encodeCall(method: getEModeCategoryDataMethod, parameters: [categoryId])
    }

    static func getReserveAddressByIdCall(reserveIndex: Int) throws -> String {
        try encodeCall(method: getReserveAddressByIdMethod, parameters: [BigUInt(reserveIndex)])
    }

    static func addressesProviderCall() throws -> String {
        try encodeCall(method: addressesProviderMethod, parameters: [])
    }

    static func getPriceOracleCall() throws -> String {
        try encodeCall(method: getPriceOracleMethod, parameters: [])
    }

    static func getAssetPriceCall(asset: AccountId) throws -> String {
        try encodeCall(method: getAssetPriceMethod, parameters: [ethereumAddress(asset)])
    }

    static func decodeUserAccountData(response: String) throws -> HydraAave.UserAccountData {
        let result = try decodeResponse(response, method: getUserAccountDataMethod)

        guard
            let totalCollateralBase = result["0"] as? BigUInt,
            let totalDebtBase = result["1"] as? BigUInt,
            let currentLiquidationThreshold = result["3"] as? BigUInt,
            let healthFactor = result["5"] as? BigUInt else {
            throw HydraAave.ContractError.invalidResponse
        }

        return HydraAave.UserAccountData(
            totalCollateralBase: totalCollateralBase,
            totalDebtBase: totalDebtBase,
            currentLiquidationThreshold: currentLiquidationThreshold,
            healthFactor: healthFactor
        )
    }

    static func decodeUserConfiguration(response: String) throws -> HydraAave.UserConfiguration {
        let result = try decodeResponse(response, method: getUserConfigurationMethod)

        guard let rawValue = (result["0"] as? [Any])?.first as? BigUInt else {
            throw HydraAave.ContractError.invalidResponse
        }

        return HydraAave.UserConfiguration(rawValue: rawValue)
    }

    static func decodeUserEMode(response: String) throws -> BigUInt {
        try decodeUInt(response: response, method: getUserEModeMethod)
    }

    static func decodeEModeCategory(response: String) throws -> HydraAave.EModeCategory {
        let result = try decodeResponse(response, method: getEModeCategoryDataMethod)

        guard
            let category = result["0"] as? [Any],
            category.count == 5,
            let liquidationThreshold = category[1] as? BigUInt,
            let priceSource = category[3] as? EthereumAddress else {
            throw HydraAave.ContractError.invalidResponse
        }

        return HydraAave.EModeCategory(
            liquidationThreshold: liquidationThreshold,
            priceSource: priceSource.addressData
        )
    }

    static func decodeReserveAddress(response: String) throws -> AccountId {
        try decodeAddress(response: response, method: getReserveAddressByIdMethod)
    }

    static func decodeAddressesProvider(response: String) throws -> AccountId {
        try decodeAddress(response: response, method: addressesProviderMethod)
    }

    static func decodePriceOracle(response: String) throws -> AccountId {
        try decodeAddress(response: response, method: getPriceOracleMethod)
    }

    static func decodeAssetPrice(response: String) throws -> BigUInt {
        try decodeUInt(response: response, method: getAssetPriceMethod)
    }
}

private extension HydraAave.Contract {
    static func ethereumAddress(_ accountId: AccountId) throws -> EthereumAddress {
        guard let address = EthereumAddress(accountId) else {
            throw HydraAave.ContractError.invalidAddress
        }

        return address
    }

    static func decodeUInt(response: String, method: String) throws -> BigUInt {
        let result = try decodeResponse(response, method: method)

        guard let value = result["0"] as? BigUInt else {
            throw HydraAave.ContractError.invalidResponse
        }

        return value
    }

    static func decodeAddress(response: String, method: String) throws -> AccountId {
        let result = try decodeResponse(response, method: method)

        guard let address = result["0"] as? EthereumAddress else {
            throw HydraAave.ContractError.invalidResponse
        }

        return address.addressData
    }
}
