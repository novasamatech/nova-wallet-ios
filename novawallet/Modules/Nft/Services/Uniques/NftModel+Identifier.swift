import Foundation

extension NftModel {
    static func uniquesIdentifier(for chainId: String, classId: UInt32, instanceId: UInt32) -> String {
        "unqs" + "-" + chainId + "-" + String(classId) + "-" + String(instanceId)
    }

    static func rmrkv1Identifier(for chainId: String, identifier: String) -> String {
        "rmrkv1" + "-" + chainId + "-" + identifier
    }

    static func rmrkv2Identifier(for chainId: String, identifier: String) -> String {
        "rmrkv2" + "-" + chainId + "-" + identifier
    }
}
