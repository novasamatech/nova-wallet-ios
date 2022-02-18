import Foundation

extension NftModel {
    static func uniquesIdentifier(for chainId: String, classId: UInt32, instanceId: UInt32) -> String {
        "unqs" + "-" + chainId + "-" + String(classId) + "-" + String(instanceId)
    }
}
