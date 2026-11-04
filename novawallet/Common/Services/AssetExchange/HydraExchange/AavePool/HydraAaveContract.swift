import BigInt
import Foundation
import SubstrateSdk
import Web3Core
import web3swift

extension HydraAave {
    enum ContractError: Error {
        case invalidAddress
        case invalidCallData
        case invalidResponse
    }

    enum Contract {
        static let poolAddress = "0x1b02E051683b5cfaC5929C25E84adb26ECf87B38"

        static let getUserAccountDataMethod = "getUserAccountData"
        static let getUserConfigurationMethod = "getUserConfiguration"
        static let getUserEModeMethod = "getUserEMode"
        static let getEModeCategoryDataMethod = "getEModeCategoryData"
        static let getReserveAddressByIdMethod = "getReserveAddressById"
        static let addressesProviderMethod = "ADDRESSES_PROVIDER"
        static let getPriceOracleMethod = "getPriceOracle"
        static let getAssetPriceMethod = "getAssetPrice"

        private static let getReservesListMethod = "getReservesList"
        private static let getReserveDataMethod = "getReserveData"
        private static let addressByteLength = 20
        private static let configurationIndex = 0
        private static let reserveIdIndex = 7
        private static let aTokenIndex = 8
        private static let assetPrecompilePrefix = Data(repeating: 0, count: 15) + Data([1])
        private static let reserveDataABIType = ABI.Element.ParameterType.tuple(types: [
            .tuple(types: [.uint(bits: 256)]),
            .uint(bits: 128),
            .uint(bits: 128),
            .uint(bits: 128),
            .uint(bits: 128),
            .uint(bits: 128),
            .uint(bits: 40),
            .uint(bits: 16),
            .address,
            .address,
            .address,
            .address,
            .uint(bits: 128),
            .uint(bits: 128),
            .uint(bits: 128)
        ])

        private static let eModeCategoryABIType = ABI.Element.ParameterType.tuple(types: [
            .uint(bits: 16),
            .uint(bits: 16),
            .uint(bits: 16),
            .address,
            .string
        ])

        private static let abi: [ABI.Element] = [
            viewFunction(getReservesListMethod, inputs: [], outputs: [.array(type: .address, length: 0)]),
            viewFunction(getReserveDataMethod, inputs: [.address], outputs: [reserveDataABIType]),
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

        static func getReservesListCall() throws -> String {
            try encodeCall(method: getReservesListMethod, parameters: [])
        }

        static func getReserveDataCall(reserve: AccountId) throws -> String {
            guard let address = EthereumAddress(reserve) else {
                throw ContractError.invalidAddress
            }

            return try encodeCall(method: getReserveDataMethod, parameters: [address])
        }

        static func decodeReservesList(response: String) throws -> [AccountId] {
            let result = try decodeResponse(response, method: getReservesListMethod)

            guard let addresses = result["0"] as? [EthereumAddress] else {
                throw ContractError.invalidResponse
            }

            return addresses.map(\.addressData)
        }

        static func decodeReserveData(response: String) throws -> ReserveData {
            let result = try decodeResponse(response, method: getReserveDataMethod)

            guard
                let reserveData = result["0"] as? [Any],
                reserveData.indices.contains(aTokenIndex),
                let configuration = (reserveData[configurationIndex] as? [Any])?.first as? BigUInt,
                let reserveIndex = reserveData[reserveIdIndex] as? BigUInt,
                let address = reserveData[aTokenIndex] as? EthereumAddress else {
                throw ContractError.invalidResponse
            }

            return ReserveData(
                configuration: ReserveConfiguration(rawValue: configuration),
                index: Int(reserveIndex),
                aTokenAddress: address.addressData
            )
        }

        static func assetId(
            for address: AccountId,
            registeredAssets: [AccountId: HydraDx.AssetId]
        ) -> HydraDx.AssetId? {
            guard address.count == addressByteLength else {
                return nil
            }

            if address.prefix(assetPrecompilePrefix.count) == assetPrecompilePrefix {
                return HydraDx.AssetId(Data(address.suffix(4)).toHex(), radix: 16)
            }

            return registeredAssets[address]
        }

        static func encodeCall(method: String, parameters: [Any]) throws -> String {
            let contract = try EthereumContract(abi: abi)

            guard let data = contract.method(method, parameters: parameters, extraData: Data()) else {
                throw ContractError.invalidCallData
            }

            return data.toHex(includePrefix: true)
        }

        static func decodeResponse(_ response: String, method: String) throws -> [String: Any] {
            do {
                let data = try Data(hexString: response)
                return try EthereumContract(abi: abi).decodeReturnData(method, data: data)
            } catch {
                throw ContractError.invalidResponse
            }
        }

        private static func viewFunction(
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
    }
}
