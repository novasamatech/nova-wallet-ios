import Foundation
import SubstrateSdk

extension XcmUni {
    struct DepositAssetValue: Equatable {
        let assets: AssetFilter
        let maxAssets: UInt32
        let beneficiary: RelativeLocation

        init(
            assets: AssetFilter,
            beneficiary: RelativeLocation,
            maxAssets: UInt32 = 1
        ) {
            self.assets = assets
            self.maxAssets = maxAssets
            self.beneficiary = beneficiary
        }
    }

    struct BuyExecutionValue: Equatable {
        let fees: Asset
        let weightLimit: WeightLimit
    }

    struct DepositReserveAssetValue: Equatable {
        let assets: AssetFilter
        let dest: RelativeLocation
        let maxAssets: UInt32
        let xcm: Instructions

        init(
            assets: AssetFilter,
            dest: RelativeLocation,
            xcm: Instructions,
            maxAssets: UInt32 = 1
        ) {
            self.assets = assets
            self.dest = dest
            self.maxAssets = maxAssets
            self.xcm = xcm
        }
    }

    struct InitiateReserveWithdrawValue: Equatable {
        let assets: AssetFilter
        let reserve: RelativeLocation
        let xcm: Instructions
    }

    struct InitiateTeleportValue: Equatable {
        let assets: AssetFilter
        let dest: RelativeLocation
        let xcm: Instructions
    }

    enum Instruction: Equatable {
        case withdrawAsset(Assets)
        case depositAsset(DepositAssetValue)
        case clearOrigin
        case reserveAssetDeposited(Assets)
        case buyExecution(BuyExecutionValue)
        case depositReserveAsset(DepositReserveAssetValue)
        case receiveTeleportedAsset(Assets)
        case burnAsset(Assets)
        case initiateReserveWithdraw(InitiateReserveWithdrawValue)
        case initiateTeleport(InitiateTeleportValue)
        case other(RawName, RawValue)
    }

    typealias Instructions = [Instruction]
}

extension XcmUni.DepositAssetValue: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case assets
        case maxAssets
        case beneficiary
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assets = try container.decode(
            XcmUni.AssetFilter.self,
            forKey: .assets,
            configuration: configuration
        )

        maxAssets = switch configuration {
        case .V0, .V1, .V2:
            try container.decode(
                StringScaleMapper<UInt32>.self,
                forKey: .maxAssets
            ).value
        case .V3, .V4, .V5:
            1
        }

        beneficiary = try container.decode(
            XcmUni.RelativeLocation.self,
            forKey: .beneficiary,
            configuration: configuration
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(assets, forKey: .assets, configuration: configuration)

        switch configuration {
        case .V0, .V1, .V2:
            try container.encode(StringScaleMapper(value: maxAssets), forKey: .maxAssets)
        case .V3, .V4, .V5:
            break
        }

        try container.encode(beneficiary, forKey: .beneficiary, configuration: configuration)
    }
}

extension XcmUni.BuyExecutionValue: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case fees
        case weightLimit
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fees = try container.decode(
            XcmUni.Asset.self,
            forKey: .fees,
            configuration: configuration
        )

        weightLimit = try container.decode(
            XcmUni.WeightLimit.self,
            forKey: .weightLimit,
            configuration: configuration
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(fees, forKey: .fees, configuration: configuration)
        try container.encode(weightLimit, forKey: .weightLimit, configuration: configuration)
    }
}

extension XcmUni.DepositReserveAssetValue: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case assets
        case dest
        case maxAssets
        case xcm
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assets = try container.decode(
            XcmUni.AssetFilter.self,
            forKey: .assets,
            configuration: configuration
        )

        dest = try container.decode(
            XcmUni.RelativeLocation.self,
            forKey: .dest,
            configuration: configuration
        )

        maxAssets = switch configuration {
        case .V0, .V1, .V2:
            try container.decode(
                StringScaleMapper<UInt32>.self,
                forKey: .maxAssets
            ).value
        case .V3, .V4, .V5:
            1
        }

        xcm = try container.decode(
            XcmUni.Instructions.self,
            forKey: .xcm,
            configuration: configuration
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(assets, forKey: .assets, configuration: configuration)
        try container.encode(dest, forKey: .dest, configuration: configuration)

        switch configuration {
        case .V0, .V1, .V2:
            try container.encode(StringScaleMapper(value: maxAssets), forKey: .maxAssets)
        case .V3, .V4, .V5:
            break
        }

        try container.encode(xcm, forKey: .xcm, configuration: configuration)
    }
}

extension XcmUni.InitiateReserveWithdrawValue: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case assets
        case reserve
        case xcm
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assets = try container.decode(
            XcmUni.AssetFilter.self,
            forKey: .assets,
            configuration: configuration
        )

        reserve = try container.decode(
            XcmUni.RelativeLocation.self,
            forKey: .reserve,
            configuration: configuration
        )

        xcm = try container.decode(
            XcmUni.Instructions.self,
            forKey: .xcm,
            configuration: configuration
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(assets, forKey: .assets, configuration: configuration)
        try container.encode(reserve, forKey: .reserve, configuration: configuration)
        try container.encode(xcm, forKey: .xcm, configuration: configuration)
    }
}

extension XcmUni.InitiateTeleportValue: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case assets
        case dest
        case xcm
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assets = try container.decode(
            XcmUni.AssetFilter.self,
            forKey: .assets,
            configuration: configuration
        )

        dest = try container.decode(
            XcmUni.RelativeLocation.self,
            forKey: .dest,
            configuration: configuration
        )

        xcm = try container.decode(
            XcmUni.Instructions.self,
            forKey: .xcm,
            configuration: configuration
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(assets, forKey: .assets, configuration: configuration)
        try container.encode(dest, forKey: .dest, configuration: configuration)
        try container.encode(xcm, forKey: .xcm, configuration: configuration)
    }
}

extension XcmUni.Instruction: XcmUniCodable {
    static let fieldWithdrawAsset = "WithdrawAsset"
    static let fieldClearOrigin = "ClearOrigin"
    static let fieldReserveAssetDeposited = "ReserveAssetDeposited"
    static let fieldBuyExecution = "BuyExecution"
    static let fieldDepositAsset = "DepositAsset"
    static let fieldDepositReserveAsset = "DepositReserveAsset"
    static let fieldReceiveTeleportedAsset = "ReceiveTeleportedAsset"
    static let fieldBurnAsset = "BurnAsset"
    static let fieldInitiateReserveWithdraw = "InitiateReserveWithdraw"
    static let fieldInitiateTeleport = "InitiateTeleport"

    // swiftlint:disable:next cyclomatic_complexity
    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case Self.fieldWithdrawAsset:
            let value = try container.decode(XcmUni.Assets.self, configuration: configuration)
            self = .withdrawAsset(value)
        case Self.fieldDepositAsset:
            let value = try container.decode(XcmUni.DepositAssetValue.self, configuration: configuration)
            self = .depositAsset(value)
        case Self.fieldClearOrigin:
            self = .clearOrigin
        case Self.fieldReserveAssetDeposited:
            let value = try container.decode(XcmUni.Assets.self, configuration: configuration)
            self = .reserveAssetDeposited(value)
        case Self.fieldBuyExecution:
            let value = try container.decode(XcmUni.BuyExecutionValue.self, configuration: configuration)
            self = .buyExecution(value)
        case Self.fieldDepositReserveAsset:
            let value = try container.decode(XcmUni.DepositReserveAssetValue.self, configuration: configuration)
            self = .depositReserveAsset(value)
        case Self.fieldReceiveTeleportedAsset:
            let value = try container.decode(XcmUni.Assets.self, configuration: configuration)
            self = .receiveTeleportedAsset(value)
        case Self.fieldBurnAsset:
            let value = try container.decode(XcmUni.Assets.self, configuration: configuration)
            self = .burnAsset(value)
        case Self.fieldInitiateReserveWithdraw:
            let value = try container.decode(XcmUni.InitiateReserveWithdrawValue.self, configuration: configuration)
            self = .initiateReserveWithdraw(value)
        case Self.fieldInitiateTeleport:
            let value = try container.decode(XcmUni.InitiateTeleportValue.self, configuration: configuration)
            self = .initiateTeleport(value)
        default:
            let value = try container.decode(JSON.self)
            self = .other(type, value)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .withdrawAsset(assets):
            try container.encode(Self.fieldWithdrawAsset)
            try container.encode(assets, configuration: configuration)
        case .clearOrigin:
            try container.encode(Self.fieldClearOrigin)
            try container.encode(JSON.null)
        case let .reserveAssetDeposited(assets):
            try container.encode(Self.fieldReserveAssetDeposited)
            try container.encode(assets, configuration: configuration)
        case let .buyExecution(value):
            try container.encode(Self.fieldBuyExecution)
            try container.encode(value, configuration: configuration)
        case let .depositAsset(value):
            try container.encode(Self.fieldDepositAsset)
            try container.encode(value, configuration: configuration)
        case let .depositReserveAsset(value):
            try container.encode(Self.fieldDepositReserveAsset)
            try container.encode(value, configuration: configuration)
        case let .receiveTeleportedAsset(assets):
            try container.encode(Self.fieldReceiveTeleportedAsset)
            try container.encode(assets, configuration: configuration)
        case let .burnAsset(assets):
            try container.encode(Self.fieldBurnAsset)
            try container.encode(assets, configuration: configuration)
        case let .initiateReserveWithdraw(value):
            try container.encode(Self.fieldInitiateReserveWithdraw)
            try container.encode(value, configuration: configuration)
        case let .initiateTeleport(value):
            try container.encode(Self.fieldInitiateTeleport)
            try container.encode(value, configuration: configuration)
        case let .other(type, value):
            try container.encode(type)
            try container.encode(value)
        }
    }
}
