import Foundation
import SubstrateSdk

extension Xcm {
    struct DepositAssetValue: Encodable {
        let assets: MultiassetFilter
        @StringCodable var maxAssets: UInt32
        let beneficiary: Multilocation
    }

    struct BuyExecutionValue: Encodable {
        let fees: Multiasset
        let weightLimit: Xcm.WeightLimit
    }

    struct DepositReserveAssetValue: Encodable {
        let assets: MultiassetFilter
        @StringCodable var maxAssets: UInt32
        let dest: Multilocation
        let xcm: [Xcm.Instruction]
    }

    enum Instruction: Encodable {
        static let fieldWithdrawAsset = "WithdrawAsset"
        static let fieldClearOrigin = "ClearOrigin"
        static let fieldReserveAssetDeposited = "ReserveAssetDeposited"
        static let fieldBuyExecution = "BuyExecution"
        static let fieldDepositAsset = "DepositAsset"
        static let fieldDepositReserveAsset = "DepositReserveAsset"
        static let fieldReceiveTeleportedAsset = "ReceiveTeleportedAsset"

        case withdrawAsset([Multiasset])
        case depositAsset(DepositAssetValue)
        case clearOrigin
        case reserveAssetDeposited([Multiasset])
        case buyExecution(BuyExecutionValue)
        case depositReserveAsset(DepositReserveAssetValue)
        case receiveTeleportedAsset([Multiasset])

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
            }
        }
    }
}
