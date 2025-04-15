import Foundation

struct DAppUnknownChain {
    let chainId: String
    let name: String
    let icon: URL?
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let rpcUrl: URL
}

typealias DAppEitherChain = Either<ChainModel, DAppUnknownChain>

extension DAppEitherChain {
    var networkName: String {
        switch self {
        case let .left(knowChain):
            return knowChain.name
        case let .right(unknownChain):
            return unknownChain.name
        }
    }

    var networkIcon: URL? {
        switch self {
        case let .left(knowChain):
            return knowChain.icon
        case let .right(unknownChain):
            return unknownChain.icon
        }
    }

    var utilityAssetBalanceInfo: AssetBalanceDisplayInfo? {
        switch self {
        case let .left(knowChain):
            return knowChain.utilityAssetDisplayInfo()
        case let .right(unknownChain):
            return unknownChain.assetDisplayInfo
        }
    }

    var nativeChain: ChainModel? {
        switch self {
        case let .left(nativeChain):
            return nativeChain
        case .right:
            return nil
        }
    }
}

extension DAppEitherChain {
    static func createFromMetamask(
        chain: MetamaskChain,
        dataSource: DAppBrowserStateDataSource
    ) -> DAppEitherChain? {
        if let knownChain = dataSource.fetchChainByEthereumChainId(chain.chainId) {
            return .left(knownChain)
        } else {
            guard let rpcUrl = chain.rpcUrls.first.flatMap({ URL(string: $0) }) else {
                return nil
            }

            let unknownChain = DAppUnknownChain(
                chainId: chain.chainId,
                name: chain.chainName,
                icon: chain.iconUrls?.first.flatMap { URL(string: $0) },
                assetDisplayInfo: chain.assetDisplayInfo,
                rpcUrl: rpcUrl
            )

            return .right(unknownChain)
        }
    }
}
