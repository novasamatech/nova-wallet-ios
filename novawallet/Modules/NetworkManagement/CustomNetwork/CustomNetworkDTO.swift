import Foundation

protocol CustomNetworkSetupRequestConvertible {
    var url: String { get }
    var name: String { get }
    var currencySymbol: String { get }
    var chainId: String? { get }
    var blockExplorerURL: String? { get }
    var coingeckoURL: String? { get }
}

enum CustomNetwork {
    struct AddRequest: CustomNetworkSetupRequestConvertible {
        let networkType: CustomNetworkType
        let url: String
        let name: String
        let currencySymbol: String
        let chainId: String?
        let blockExplorerURL: String?
        let coingeckoURL: String?
    }

    struct ModifyRequest: CustomNetworkSetupRequestConvertible {
        let existingNetwork: ChainModel
        let node: ChainNodeModel
        let url: String
        let name: String
        let currencySymbol: String
        let chainId: String?
        let blockExplorerURL: String?
        let coingeckoURL: String?
    }

    struct EditRequest: CustomNetworkSetupRequestConvertible {
        let url: String
        let name: String
        let currencySymbol: String
        let chainId: String?
        let blockExplorerURL: String?
        let coingeckoURL: String?
    }

    struct SetupRequest {
        let networkType: CustomNetworkType
        let url: String
        let name: String
        let iconUrl: URL?
        let currencySymbol: String?
        let chainId: String?
        let blockExplorerURL: String?
        let coingeckoURL: String?
        let replacingNode: ChainNodeModel?
        let networkSetupType: CustomNetworkSetupOperationType

        init(
            from request: CustomNetworkSetupRequestConvertible,
            networkType: CustomNetworkType,
            iconUrl: URL? = nil,
            replacingNode: ChainNodeModel? = nil,
            networkSetupType: CustomNetworkSetupOperationType
        ) {
            self.networkType = networkType
            url = request.url
            name = request.name
            self.iconUrl = iconUrl
            currencySymbol = request.currencySymbol
            chainId = request.chainId
            blockExplorerURL = request.blockExplorerURL
            coingeckoURL = request.coingeckoURL
            self.replacingNode = replacingNode
            self.networkSetupType = networkSetupType
        }

        init(
            networkType: CustomNetworkType,
            url: String,
            name: String,
            iconUrl: URL?,
            currencySymbol: String? = nil,
            chainId: String? = nil,
            blockExplorerURL: String? = nil,
            coingeckoURL: String? = nil,
            replacingNode: ChainNodeModel? = nil,
            networkSetupType: CustomNetworkSetupOperationType
        ) {
            self.networkType = networkType
            self.url = url
            self.name = name
            self.iconUrl = iconUrl
            self.currencySymbol = currencySymbol
            self.chainId = chainId
            self.blockExplorerURL = blockExplorerURL
            self.coingeckoURL = coingeckoURL
            self.replacingNode = replacingNode
            self.networkSetupType = networkSetupType
        }
    }
}
