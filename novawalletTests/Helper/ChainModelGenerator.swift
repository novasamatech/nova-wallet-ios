import Foundation
@testable import novawallet
import SubstrateSdk

enum ChainModelGenerator {
    static func generate(
        count: Int,
        withTypes: Bool = true,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false,
        hasGovernance: Bool = false,
        hasSubstrateRuntime: Bool = true
    ) -> [ChainModel] {
        (0 ..< count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = AssetModel(
                assetId: UInt32(index),
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                priceId: nil,
                stakings: hasStaking ? [.relaychain] : nil,
                type: nil,
                typeExtras: nil,
                buyProviders: nil,
                sellProviders: nil,
                displayPriority: nil,
                enabled: true,
                source: .remote
            )

            let node = ChainNodeModel(
                url: "wss://node.io/\(chainId)",
                name: chainId,
                order: 0,
                features: nil,
                source: .remote
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            var options: [LocalChainOptions] = []

            if hasCrowdloans {
                options.append(.crowdloans)
            }

            if hasGovernance {
                options.append(.governance)
            }

            if !hasSubstrateRuntime {
                options.append(.noSubstrateRuntime)
            }

            let externalApis = generateExternaApis(
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
                nodeSwitchStrategy: .roundRobin,
                addressPrefix: ChainModel.AddressPrefix(index),
                legacyAddressPrefix: nil,
                types: types,
                icon: URL(string: "https://github.com")!,
                options: options.isEmpty ? nil : options,
                externalApis: externalApis,
                explorers: explorers,
                order: Int64(index),
                additional: nil,
                syncMode: .full,
                source: .remote,
                connectionMode: .autoBalanced
            )
        }
    }

    static func generateRemote(
        count: Int,
        withTypes: Bool = true,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false,
        hasSubstrateRuntime: Bool = true,
        fullSyncByDefault: Bool = true
    ) -> [RemoteChainModel] {
        (0 ..< count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let asset = RemoteAssetModel(
                assetId: UInt32(index),
                icon: nil,
                name: chainId,
                symbol: chainId.prefix(3).uppercased(),
                precision: 12,
                priceId: nil,
                staking: hasStaking ? ["relaychain"] : nil,
                type: nil,
                typeExtras: nil,
                buyProviders: nil,
                sellProviders: nil,
                displayPriority: nil
            )

            let node = RemoteChainNodeModel(
                url: "wss://node.io/\(chainId)",
                name: chainId,
                features: nil
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            var options: [String] = []

            if hasCrowdloans {
                options.append(LocalChainOptions.crowdloans.rawValue)
            }

            if !hasSubstrateRuntime {
                options.append(LocalChainOptions.noSubstrateRuntime.rawValue)
            }

            if fullSyncByDefault {
                options.append(RemoteOnlyChainOptions.fullSyncByDefault.rawValue)
            }

            let externalApi = generateRemoteExternaApis(
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
                nodeSelectionStrategy: nil,
                addressPrefix: ChainModel.AddressPrefix(index),
                legacyAddressPrefix: nil,
                types: types,
                icon: URL(string: "https://github.com")!,
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
        addressPrefix: ChainModel.AddressPrefix,
        assetPresicion: UInt16 = (9 ... 18).randomElement()!,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false,
        hasSubstrateRuntime: Bool = true,
        isEthereumBased: Bool = false,
        hasProxy: Bool = true,
        hasMultisig: Bool = true,
        enabled: Bool = true
    ) -> ChainModel {
        let assets = (0 ..< count).map { index in
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
            hasCrowdloans: hasCrowdloans,
            hasSubstrateRuntime: hasSubstrateRuntime,
            isEthereumBased: isEthereumBased,
            hasProxy: hasProxy,
            hasMultisig: hasMultisig,
            enabled: enabled
        )
    }

    static func generateChain(
        assets: [AssetModel],
        defaultChainId: ChainModel.Id? = nil,
        addressPrefix: ChainModel.AddressPrefix,
        assetPresicion _: UInt16 = (9 ... 18).randomElement()!,
        hasStaking: Bool = false,
        hasCrowdloans: Bool = false,
        hasSubstrateRuntime: Bool = true,
        isEthereumBased: Bool = false,
        hasProxy: Bool = true,
        hasMultisig: Bool = true,
        enabled: Bool = true
    ) -> ChainModel {
        let chainId = defaultChainId ?? Data.random(of: 32)!.toHex()

        let urlString = "node\(Data.random(of: 32)!.toHex()).io"

        let node = ChainNodeModel(
            url: urlString,
            name: UUID().uuidString,
            order: 0,
            features: nil,
            source: .remote
        )

        var options: [LocalChainOptions] = []

        if hasCrowdloans {
            options.append(.crowdloans)
        }

        if !hasSubstrateRuntime {
            options.append(.noSubstrateRuntime)
        }

        if hasProxy {
            options.append(.proxy)
        }

        if hasMultisig {
            options.append(.multisig)
        }

        if isEthereumBased {
            options.append(.ethereumBased)
        }

        let externalApis = generateExternaApis(
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
            nodeSwitchStrategy: .roundRobin,
            addressPrefix: addressPrefix,
            legacyAddressPrefix: nil,
            types: nil,
            icon: Constants.dummyURL,
            options: options.isEmpty ? nil : options,
            externalApis: externalApis,
            explorers: explorers,
            order: 0,
            additional: nil,
            syncMode: enabled ? .full : .disabled,
            source: .remote,
            connectionMode: .autoBalanced
        )
    }

    static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        symbol: String? = nil,
        assetPresicion: UInt16 = (9 ... 18).randomElement()!,
        hasStaking: Bool = false,
        buyProviders: JSON? = nil,
        sellProviders: JSON? = nil,
        enabled: Bool = true,
        source: AssetModel.Source = .remote
    ) -> AssetModel {
        let assetSymbol = symbol ?? String(UUID().uuidString.prefix(3))

        return AssetModel(
            assetId: identifier,
            icon: nil,
            name: UUID().uuidString,
            symbol: assetSymbol,
            precision: assetPresicion,
            priceId: nil,
            stakings: hasStaking ? [.relaychain] : nil,
            type: nil,
            typeExtras: nil,
            buyProviders: buyProviders,
            sellProviders: sellProviders,
            displayPriority: nil,
            enabled: enabled,
            source: source
        )
    }

    private static func generateRemoteExternaApis(
        for chainId: ChainModel.Id,
        hasStaking: Bool,
        hasCrowdloans: Bool
    ) -> RemoteChainExternalApiSet? {
        guard let externalApis = generateExternaApis(
            for: chainId,
            hasStaking: hasStaking,
            hasCrowdloans: hasCrowdloans
        ) else {
            return nil
        }

        return .init(
            staking: externalApis.staking()?.map(generateRemoteExternal(from:)),
            stakingRewards: externalApis.stakingRewards()?.map(generateRemoteExternal(from:)),
            history: externalApis.history()?.map(generateRemoteExternal(from:)),
            crowdloans: externalApis.crowdloans()?.map(generateRemoteExternal(from:)),
            governance: externalApis.governance()?.map(generateRemoteExternal(from:)),
            goverananceDelegations: externalApis.governanceDelegations()?.map(generateRemoteExternal(from:)),
            referendumSummary: externalApis.referendumSummary()?.map(generateRemoteExternal(from:)),
            multisig: externalApis.multisig()?.map(generateRemoteExternal(from:))
        )
    }

    private static func generateRemoteExternal(from local: LocalChainExternalApi) -> RemoteChainExternalApi {
        .init(type: local.serviceType, url: local.url, parameters: local.parameters)
    }

    private static func generateExternaApis(
        for chainId: ChainModel.Id,
        hasStaking: Bool,
        hasCrowdloans: Bool
    ) -> LocalChainExternalApiSet? {
        var apis = Set<LocalChainExternalApi>()

        if hasCrowdloans {
            let crowdloanApi = LocalChainExternalApi(
                apiType: LocalChainApiExternalType.crowdloans.rawValue,
                serviceType: "test",
                url: URL(string: "https://crowdloan.io/\(chainId)-\(UUID().uuidString).json")!,
                parameters: nil
            )

            apis.insert(crowdloanApi)
        }

        if hasStaking {
            let stakingApi = LocalChainExternalApi(
                apiType: LocalChainApiExternalType.staking.rawValue,
                serviceType: "test",
                url: URL(string: "https://staking.io/\(chainId)-\(UUID().uuidString).json")!,
                parameters: nil
            )
            let stakingRewardsApi = LocalChainExternalApi(
                apiType: LocalChainApiExternalType.stakingRewards.rawValue,
                serviceType: "test",
                url: URL(string: "https://staking.io/\(chainId)-\(UUID().uuidString).json")!,
                parameters: nil
            )

            apis.insert(stakingApi)
            apis.insert(stakingRewardsApi)
        }

        if !apis.isEmpty {
            return .init(localApis: apis)
        } else {
            return nil
        }
    }

    static func generateChainColor() -> String {
        "linear-gradient(315deg, #D43079 0%, #F93C90 100%)"
    }

    static func generateEvmToken(chainId1: ChainModel.Id, chainId2: ChainModel.Id) -> RemoteEvmToken {
        RemoteEvmToken(
            symbol: "USDT",
            precision: 6,
            name: "Tether USD",
            priceId: "tether",
            icon: nil,
            instances: [
                .init(
                    chainId: chainId1,
                    contractAddress: "0xeFAeeE334F0Fd1712f9a8cc375f427D9Cdd40d73",
                    buyProviders: nil,
                    sellProviders: nil
                ),
                .init(
                    chainId: chainId2,
                    contractAddress: "0xB44a9B6905aF7c801311e8F4E76932ee959c663C",
                    buyProviders: nil,
                    sellProviders: nil
                )
            ],
            displayPriority: nil
        )
    }
}
