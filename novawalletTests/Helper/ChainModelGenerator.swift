import Foundation
@testable import novawallet
import SubstrateSdk

enum ChainModelGenerator {
    static func generate(
        count: Int,
        withTypes: Bool = true,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false
    ) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                priceId: nil,
                staking: hasStaking ? "relaychain" : nil,
                type: nil,
                typeExtras: nil,
                buyProviders: nil
            )

            let node = ChainNodeModel(
                url: URL(string: "wss://node.io/\(chainId)")!,
                name: chainId,
                apikey: nil,
                order: 0
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            var options: [ChainOptions] = []

            if hasCrowdloans {
                options.append(.crowdloans)
            }

            let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
                for: chainId,
                hasStaking: hasStaking,
                hasCrowdloans: hasCrowdloans
            )

            let explorers: [ChainModel.Explorer] = [
                ChainModel.Explorer(
                    name: UUID().uuidString,
                    account: "https://github.com/{address}",
                    extrinsic: nil,
                    event: nil
                )
            ]

            return ChainModel(
                chainId: chainId,
                parentId: nil,
                name: String(chainId.reversed()),
                assets: [asset],
                nodes: [node],
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                color: generateChainColor(),
                options: options.isEmpty ? nil : options,
                externalApi: externalApi,
                explorers: explorers,
                order: Int64(index),
                additional: nil
            )
        }
    }

    static func generateRemote(
        count: Int,
        withTypes: Bool = true,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false
    ) -> [RemoteChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                priceId: nil,
                staking: hasStaking ? "relaychain" : nil,
                type: nil,
                typeExtras: nil,
                buyProviders: nil
            )

            let node = RemoteChainNodeModel(
                url: URL(string: "wss://node.io/\(chainId)")!,
                name: chainId,
                apikey: nil
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            var options: [ChainOptions] = []

            if hasCrowdloans {
                options.append(.crowdloans)
            }

            let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
                for: chainId,
                hasStaking: hasStaking,
                hasCrowdloans: hasCrowdloans
            )

            let explorers: [ChainModel.Explorer] = [
                ChainModel.Explorer(
                    name: UUID().uuidString,
                    account: "https://github.com/{address}",
                    extrinsic: nil,
                    event: nil
                )
            ]

            return RemoteChainModel(
                chainId: chainId,
                parentId: nil,
                name: String(chainId.reversed()),
                assets: [asset],
                nodes: [node],
                addressPrefix: UInt16(index),
                types: types,
                icon: URL(string: "https://github.com")!,
                color: generateChainColor(),
                options: options.isEmpty ? nil : options,
                externalApi: externalApi,
                explorers: explorers,
                additional: nil
            )
        }
    }

    static func generateChain(
        defaultChainId: ChainModel.Id? = nil,
        generatingAssets count: Int,
        addressPrefix: UInt16,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false
    ) -> ChainModel {
        let assets = (0..<count).map { index in
            generateAssetWithId(
                AssetModel.Id(index),
                assetPresicion: assetPresicion,
                hasStaking: hasStaking
            )
        }

        return generateChain(
            assets: assets,
            defaultChainId: defaultChainId,
            addressPrefix: addressPrefix,
            assetPresicion: assetPresicion,
            hasStaking: hasStaking,
            hasCrowdloans: hasCrowdloans
        )
    }

    static func generateChain(
        assets: [AssetModel],
        defaultChainId: ChainModel.Id? = nil,
        addressPrefix: UInt16,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false
    ) -> ChainModel {
        let chainId = defaultChainId ?? Data.random(of: 32)!.toHex()

        let urlString = "node\(Data.random(of: 32)!.toHex()).io"

        let node = ChainNodeModel(
            url: URL(string: urlString)!,
            name: UUID().uuidString,
            apikey: nil,
            order: 0
        )

        var options: [ChainOptions] = []

        if hasCrowdloans {
            options.append(.crowdloans)
        }

        let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
            for: chainId,
            hasStaking: hasStaking,
            hasCrowdloans: hasCrowdloans
        )

        let explorers: [ChainModel.Explorer] = [
            ChainModel.Explorer(
                name: UUID().uuidString,
                account: "https://github.com/{address}",
                extrinsic: nil,
                event: nil
            )
        ]

        return ChainModel(
            chainId: chainId,
            parentId: nil,
            name: UUID().uuidString,
            assets: Set(assets),
            nodes: [node],
            addressPrefix: addressPrefix,
            types: nil,
            icon: Constants.dummyURL,
            color: generateChainColor(),
            options: options.isEmpty ? nil : options,
            externalApi: externalApi,
            explorers: explorers,
            order: 0,
            additional: nil
        )
    }

    static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        symbol: String? = nil,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        hasStaking: Bool = false,
        buyProviders: JSON? = nil
    ) -> AssetModel {

        let assetSymbol = symbol ?? String(UUID().uuidString.prefix(3))

        return AssetModel(
            assetId: identifier,
            icon: Constants.dummyURL,
            name: UUID().uuidString,
            symbol: assetSymbol,
            precision: assetPresicion,
            priceId: nil,
            staking: hasStaking ? "relaychain" : nil,
            type: nil,
            typeExtras: nil,
            buyProviders: buyProviders
        )
    }

    private static func generateExternaApis(
        for chainId: ChainModel.Id,
        hasStaking: Bool,
        hasCrowdloans: Bool
    ) -> ChainModel.ExternalApiSet? {
        let crowdloanApi: ChainModel.ExternalApi?

        if hasCrowdloans {
            crowdloanApi = ChainModel.ExternalApi(
                type: "test",
                url: URL(string: "https://crowdloan.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            crowdloanApi = nil
        }

        let stakingApi: ChainModel.ExternalApi?

        if hasStaking {
            stakingApi = ChainModel.ExternalApi(
                type: "test",
                url: URL(string: "https://staking.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            stakingApi = nil
        }

        if crowdloanApi != nil || stakingApi != nil {
            return ChainModel.ExternalApiSet(staking: stakingApi, history: nil, crowdloans: crowdloanApi)
        } else {
            return nil
        }
    }

    static func generateChainColor() -> String {
        "linear-gradient(315deg, #D43079 0%, #F93C90 100%)"
    }
}
