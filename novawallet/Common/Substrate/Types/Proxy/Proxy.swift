import Foundation
import SubstrateSdk
import BigInt

enum Proxy {
    static var moduleName: String {
        "proxy"
    }

    struct ProxyDefinition: Decodable, Equatable {
        let delegate: AccountId
        let proxyType: ProxyType
        @StringCodable var delay: BlockNumber
        
        enum CodingKeys: CodingKey {
            case delegate
            case proxyType = "proxy_type"
            case delay
        }
    }
    
    enum ProxyType: Decodable {
        case any
        case nonTransfer
        case cancelProxy
        case assets
        case assetOwner
        case assetManager
        case collator
        
        enum Field {
            static let any = "Any"
            static let nonTransfer = "NonTransfer"
            static let cancelProxy = "CancelProxy"
            static let assets = "Assets"
            static let assetOwner = "AssetOwner"
            static let assetManager = "AssetManager"
            static let collator = "Collator"
        }
        
        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)
            
            switch type {
            case Field.any:
                self = .any
            case Field.nonTransfer:
                self = .nonTransfer
            case Field.cancelProxy:
                self = .cancelProxy
            case Field.assets:
                self = .assets
            case Field.assetOwner:
                self = .assetOwner
            case Field.assetManager:
                self = .assetManager
            case Field.collator:
                self = .collator
            default:
                throw CommonError.dataCorruption
            }
        }
    }
}
