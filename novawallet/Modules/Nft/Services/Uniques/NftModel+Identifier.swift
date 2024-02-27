import Foundation

extension NftModel {
    static func uniquesIdentifier(for chainId: ChainModel.Id, classId: UInt32, instanceId: UInt32) -> String {
        "unqs" + "-" + chainId + "-" + String(classId) + "-" + String(instanceId)
    }

    static func rmrkv1Identifier(for chainId: ChainModel.Id, identifier: String) -> String {
        "rmrkv1" + "-" + chainId + "-" + identifier
    }

    static func rmrkv2Identifier(for chainId: ChainModel.Id, identifier: String) -> String {
        "rmrkv2" + "-" + chainId + "-" + identifier
    }

    static func pdc20Identifier(for chainId: ChainModel.Id, token: String, address: String) -> String {
        "pdc20" + "-" + chainId + "-" + token + "-" + address
    }

    static func kodaDotIdentifier(for chainId: ChainModel.Id, identifier: String) -> String {
        "kodadot" + "-" + chainId + "-" + identifier
    }
}
