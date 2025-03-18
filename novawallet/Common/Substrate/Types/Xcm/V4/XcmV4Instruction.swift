import Foundation
import SubstrateSdk

extension XcmV4 {
    struct DepositAssetValue: Codable {
        let assets: XcmV4.AssetFilter
        let beneficiary: XcmV4.Multilocation
    }

    struct BuyExecutionValue: Codable {
        let fees: XcmV4.Multiasset
        let weightLimit: Xcm.WeightLimit<BlockchainWeight.WeightV2>
    }

    struct DepositReserveAssetValue: Codable {
        let assets: XcmV4.AssetFilter
        let dest: XcmV4.Multilocation
        let xcm: [Instruction]
    }

    enum Instruction: Codable {
        static let fieldWithdrawAsset = "WithdrawAsset"
        static let fieldClearOrigin = "ClearOrigin"
        static let fieldReserveAssetDeposited = "ReserveAssetDeposited"
        static let fieldBuyExecution = "BuyExecution"
        static let fieldDepositAsset = "DepositAsset"
        static let fieldDepositReserveAsset = "DepositReserveAsset"
        static let fieldReceiveTeleportedAsset = "ReceiveTeleportedAsset"

        case withdrawAsset([XcmV4.Multiasset])
        case depositAsset(DepositAssetValue)
        case clearOrigin
        case reserveAssetDeposited([XcmV4.Multiasset])
        case buyExecution(BuyExecutionValue)
        case depositReserveAsset(DepositReserveAssetValue)
        case receiveTeleportedAsset([XcmV4.Multiasset])
        case other(String, JSON)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case Self.fieldWithdrawAsset:
                let value = try container.decode([XcmV4.Multiasset].self)
                self = .withdrawAsset(value)
            case Self.fieldDepositAsset:
                let value = try container.decode(DepositAssetValue.self)
                self = .depositAsset(value)
            case Self.fieldClearOrigin:
                self = .clearOrigin
            case Self.fieldReserveAssetDeposited:
                let value = try container.decode([XcmV4.Multiasset].self)
                self = .reserveAssetDeposited(value)
            case Self.fieldBuyExecution:
                let value = try container.decode(BuyExecutionValue.self)
                self = .buyExecution(value)
            case Self.fieldDepositReserveAsset:
                let value = try container.decode(DepositReserveAssetValue.self)
                self = .depositReserveAsset(value)
            case Self.fieldReceiveTeleportedAsset:
                let value = try container.decode([XcmV4.Multiasset].self)
                self = .receiveTeleportedAsset(value)
            default:
                let value = try container.decode(JSON.self)
                self = .other(type, value)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .withdrawAsset(assets):
                try container.encode(Self.fieldWithdrawAsset)
                try container.encode(assets)
            case .clearOrigin:
                try container.encode(Self.fieldClearOrigin)
                try container.encode(JSON.null)
            case let .reserveAssetDeposited(assets):
                try container.encode(Self.fieldReserveAssetDeposited)
                try container.encode(assets)
            case let .buyExecution(value):
                try container.encode(Self.fieldBuyExecution)
                try container.encode(value)
            case let .depositAsset(value):
                try container.encode(Self.fieldDepositAsset)
                try container.encode(value)
            case let .depositReserveAsset(value):
                try container.encode(Self.fieldDepositReserveAsset)
                try container.encode(value)
            case let .receiveTeleportedAsset(assets):
                try container.encode(Self.fieldReceiveTeleportedAsset)
                try container.encode(assets)
            case let .other(type, value):
                try container.encode(type)
                try container.encode(value)
            }
        }
    }
}
