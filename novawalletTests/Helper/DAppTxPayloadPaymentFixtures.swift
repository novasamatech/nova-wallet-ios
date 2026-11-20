import BigInt
import Foundation
@testable import novawallet
import SubstrateSdk

/// Payment extensions of Polkadot Asset Hub written the way a dApp sends them and a chain that takes them.
enum DAppTxPayloadPaymentFixture {
    static let usdtSymbol = "USDT"

    /// SCALE of `Location { parents: 0, interior: X2(PalletInstance(50), GeneralIndex(1984)) }`
    static let usdtLocation = Data([0x00, 0x02, 0x04, 0x32, 0x05, 0x01, 0x1F])

    /// The same location with `GeneralIndex(9999)`: an asset the wallet's chain doesn't list
    static let unlistedAssetLocation = Data([0x00, 0x02, 0x04, 0x32, 0x05, 0x3D, 0x9C])

    /// The explicit part of `ChargeAssetTxPayment`: the compact tip and the optional fee asset
    static func assetPayment(tip: BigUInt, assetLocation: Data? = nil) throws -> Data {
        let asset = assetLocation.map { Data([1]) + $0 } ?? Data([0])

        return try DAppTxPayloadFixture.scale(tip) + asset
    }

    /// A chain with the genesis of `ExtrinsicGolden` that accepts fees in assets as Asset Hub does and lists USDT.
    static func makeAssetHubChain() throws -> ChainModel {
        let native = ChainModelGenerator.generateAssetWithId(0, symbol: "DOT", assetPresicion: 10)

        let usdt = AssetModel(
            assetId: 1,
            icon: nil,
            name: "Tether USD",
            symbol: usdtSymbol,
            precision: 6,
            priceId: nil,
            stakings: nil,
            type: AssetType.statemine.rawValue,
            typeExtras: .dictionaryValue(["assetId": .stringValue("1984")]),
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let template = ChainModelGenerator.generateChain(
            assets: [native, usdt],
            defaultChainId: try Data(hexString: ExtrinsicGolden.genesisHash).toHex(),
            addressPrefix: 0
        )

        return ChainModel(
            chainId: template.chainId,
            parentId: template.parentId,
            name: template.name,
            assets: template.assets,
            nodes: template.nodes,
            nodeSwitchStrategy: template.nodeSwitchStrategy,
            addressPrefix: template.addressPrefix,
            legacyAddressPrefix: template.legacyAddressPrefix,
            types: template.types,
            icon: template.icon,
            options: (template.options ?? []) + [.assetHubFees],
            externalApis: template.externalApis,
            explorers: template.explorers,
            order: template.order,
            additional: template.additional,
            syncMode: template.syncMode,
            source: template.source,
            connectionMode: template.connectionMode
        )
    }
}
