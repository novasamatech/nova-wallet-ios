import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct SubnetIdentity: Decodable, Equatable {
        @BytesCodable var subnetName: Data
        @BytesCodable var githubRepo: Data
        @BytesCodable var subnetContact: Data
        @BytesCodable var subnetUrl: Data
        @BytesCodable var discord: Data
        @BytesCodable var description: Data
        @BytesCodable var logoUrl: Data
        @BytesCodable var additional: Data
    }

    struct DynamicInfo: Decodable, Equatable {
        @StringCodable var netuid: UInt16
        @BytesCodable var ownerHotkey: AccountId
        @BytesCodable var ownerColdkey: AccountId
        @BytesCodable var subnetName: Data
        @BytesCodable var tokenSymbol: Data
        @StringCodable var tempo: UInt16
        @StringCodable var lastStep: UInt64
        @StringCodable var blocksSinceLastStep: UInt64
        @StringCodable var emission: Balance
        @StringCodable var alphaIn: Balance
        @StringCodable var alphaOut: Balance
        @StringCodable var taoIn: Balance
        @StringCodable var alphaOutEmission: Balance
        @StringCodable var alphaInEmission: Balance
        @StringCodable var taoInEmission: Balance
        @StringCodable var pendingAlphaEmission: Balance
        @StringCodable var pendingRootEmission: Balance
        @StringCodable var subnetVolume: Balance
        @StringCodable var networkRegisteredAt: UInt64
        let subnetIdentity: SubnetIdentity?
        let movingPrice: JSON

        var displayName: String {
            String(decoding: subnetName, as: UTF8.self)
        }

        var displaySymbol: String {
            String(decoding: tokenSymbol, as: UTF8.self)
        }
    }
}
