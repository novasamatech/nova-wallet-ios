import Foundation

extension Xcm {
    enum Instruction: Encodable {
        static let fieldWithdrawAsset = "WithdrawAsset"
        static let fieldClearOrigin = "ClearOrigin"
        static let fieldReserveAssetDeposited = "ReserveAssetDeposited"
        static let fieldBuyExecution = "BuyExecution"
        static let fieldDepositAsset = "DepositAsset"

        case withdrawAsset([Multiasset])
        case depositAsset(MultiassetFilter, UInt32, Multilocation)
        case clearOrigin
        case reserveAssetDeposited([Multiasset])
        case buyExecution(fees: Multiasset, weightLimit: Xcm.WeightLimit)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .withdrawAsset(assets):
                try container.encode(Self.fieldWithdrawAsset)
                try container.encode(assets)
            case .clearOrigin:
                try container.encode(Self.fieldClearOrigin)
            case let .reserveAssetDeposited(assets):
                try container.encode(Self.fieldReserveAssetDeposited)
                try container.encode(assets)
            case let .buyExecution(fees, weightLimit):
                try container.encode(Self.fieldBuyExecution)
                try container.encode(fees)
                try container.encode(weightLimit)
            case let .depositAsset(assets, maxAssets, beneficiary):
                try container.encode(Self.fieldDepositAsset)
                try container.encode(assets)
                try container.encode(maxAssets)
                try container.encode(beneficiary)
            }
        }
    }
}
