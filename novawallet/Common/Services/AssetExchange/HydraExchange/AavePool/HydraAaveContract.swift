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

        private static let getReservesListMethod = "getReservesList"
        private static let getReserveDataMethod = "getReserveData"
        private static let addressByteLength = 20
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

        // Minimal interface from deployments/hydration/Pool-Implementation.json
        // in galacticcouncil/money-market.
        private static let abi: [ABI.Element] = [
            .function(
                .init(
                    name: getReservesListMethod,
                    inputs: [],
                    outputs: [
                        .init(name: "", type: .array(type: .address, length: 0))
                    ],
                    constant: true,
                    payable: false
                )
            ),
            .function(
                .init(
                    name: getReserveDataMethod,
                    inputs: [
                        .init(name: "asset", type: .address)
                    ],
                    outputs: [
                        .init(name: "", type: reserveDataABIType)
                    ],
                    constant: true,
                    payable: false
                )
            )
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

        static func decodeATokenAddress(response: String) throws -> AccountId {
            let result = try decodeResponse(response, method: getReserveDataMethod)

            guard
                let reserveData = result["0"] as? [Any],
                reserveData.indices.contains(aTokenIndex),
                let address = reserveData[aTokenIndex] as? EthereumAddress else {
                throw ContractError.invalidResponse
            }

            return address.addressData
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

        private static func encodeCall(method: String, parameters: [Any]) throws -> String {
            let contract = try EthereumContract(abi: abi)

            guard let data = contract.method(method, parameters: parameters, extraData: Data()) else {
                throw ContractError.invalidCallData
            }

            return data.toHex(includePrefix: true)
        }

        private static func decodeResponse(_ response: String, method: String) throws -> [String: Any] {
            do {
                let data = try Data(hexString: response)
                return try EthereumContract(abi: abi).decodeReturnData(method, data: data)
            } catch {
                throw ContractError.invalidResponse
            }
        }
    }
}
