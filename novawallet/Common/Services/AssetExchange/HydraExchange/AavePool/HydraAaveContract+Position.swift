import BigInt
import Foundation
import Operation_iOS
import SubstrateSdk
import Web3Core
import web3swift

extension HydraAave.Contract {
    private static let getUserAccountDataMethod = "getUserAccountData"
    private static let getUserConfigurationMethod = "getUserConfiguration"
    private static let getUserEModeMethod = "getUserEMode"
    private static let getEModeCategoryDataMethod = "getEModeCategoryData"
    private static let getReserveAddressByIdMethod = "getReserveAddressById"
    private static let addressesProviderMethod = "ADDRESSES_PROVIDER"
    private static let getPriceOracleMethod = "getPriceOracle"
    private static let getAssetPriceMethod = "getAssetPrice"

    private static let eModeCategoryABIType = ABI.Element.ParameterType.tuple(types: [
        .uint(bits: 16),
        .uint(bits: 16),
        .uint(bits: 16),
        .address,
        .string
    ])

    private static let positionAbi: [ABI.Element] = [
        viewFunction(
            getUserAccountDataMethod,
            inputs: [.address],
            outputs: Array(repeating: .uint(bits: 256), count: 6)
        ),
        viewFunction(
            getUserConfigurationMethod,
            inputs: [.address],
            outputs: [.tuple(types: [.uint(bits: 256)])]
        ),
        viewFunction(getUserEModeMethod, inputs: [.address], outputs: [.uint(bits: 256)]),
        viewFunction(getEModeCategoryDataMethod, inputs: [.uint(bits: 8)], outputs: [eModeCategoryABIType]),
        viewFunction(getReserveAddressByIdMethod, inputs: [.uint(bits: 16)], outputs: [.address]),
        viewFunction(addressesProviderMethod, inputs: [], outputs: [.address]),
        viewFunction(getPriceOracleMethod, inputs: [], outputs: [.address]),
        viewFunction(getAssetPriceMethod, inputs: [.address], outputs: [.uint(bits: 256)])
    ]

    static func createCallOperation(
        connection: JSONRPCEngine,
        contract: String,
        data: String
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
            parameters: params
        )
    }

    static func getUserAccountDataCall(user: AccountId) throws -> String {
        try encodePositionCall(method: getUserAccountDataMethod, parameters: [ethereumAddress(user)])
    }

    static func getUserConfigurationCall(user: AccountId) throws -> String {
        try encodePositionCall(method: getUserConfigurationMethod, parameters: [ethereumAddress(user)])
    }

    static func getUserEModeCall(user: AccountId) throws -> String {
        try encodePositionCall(method: getUserEModeMethod, parameters: [ethereumAddress(user)])
    }

    static func getEModeCategoryDataCall(categoryId: BigUInt) throws -> String {
        try encodePositionCall(method: getEModeCategoryDataMethod, parameters: [categoryId])
    }

    static func getReserveAddressByIdCall(reserveIndex: Int) throws -> String {
        try encodePositionCall(method: getReserveAddressByIdMethod, parameters: [BigUInt(reserveIndex)])
    }

    static func addressesProviderCall() throws -> String {
        try encodePositionCall(method: addressesProviderMethod, parameters: [])
    }

    static func getPriceOracleCall() throws -> String {
        try encodePositionCall(method: getPriceOracleMethod, parameters: [])
    }

    static func getAssetPriceCall(asset: AccountId) throws -> String {
        try encodePositionCall(method: getAssetPriceMethod, parameters: [ethereumAddress(asset)])
    }

    static func decodeUserAccountData(response: String) throws -> HydraAave.UserAccountData {
        let result = try decodeResponse(response, method: getUserAccountDataMethod, abi: positionAbi)

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
        let result = try decodeResponse(response, method: getUserConfigurationMethod, abi: positionAbi)

        guard let rawValue = (result["0"] as? [Any])?.first as? BigUInt else {
            throw HydraAave.ContractError.invalidResponse
        }

        return HydraAave.UserConfiguration(rawValue: rawValue)
    }

    static func decodeUserEMode(response: String) throws -> BigUInt {
        try decodeUInt(response: response, method: getUserEModeMethod)
    }

    static func decodeEModeCategory(response: String) throws -> HydraAave.EModeCategory {
        let result = try decodeResponse(response, method: getEModeCategoryDataMethod, abi: positionAbi)

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
    static func viewFunction(
        _ name: String,
        inputs: [ABI.Element.ParameterType],
        outputs: [ABI.Element.ParameterType]
    ) -> ABI.Element {
        .function(
            .init(
                name: name,
                inputs: inputs.map { .init(name: "", type: $0) },
                outputs: outputs.map { .init(name: "", type: $0) },
                constant: true,
                payable: false
            )
        )
    }

    static func ethereumAddress(_ accountId: AccountId) throws -> EthereumAddress {
        guard let address = EthereumAddress(accountId) else {
            throw HydraAave.ContractError.invalidAddress
        }

        return address
    }

    static func encodePositionCall(method: String, parameters: [Any]) throws -> String {
        try encodeCall(method: method, parameters: parameters, abi: positionAbi)
    }

    static func decodeUInt(response: String, method: String) throws -> BigUInt {
        let result = try decodeResponse(response, method: method, abi: positionAbi)

        guard let value = result["0"] as? BigUInt else {
            throw HydraAave.ContractError.invalidResponse
        }

        return value
    }

    static func decodeAddress(response: String, method: String) throws -> AccountId {
        let result = try decodeResponse(response, method: method, abi: positionAbi)

        guard let address = result["0"] as? EthereumAddress else {
            throw HydraAave.ContractError.invalidResponse
        }

        return address.addressData
    }
}
