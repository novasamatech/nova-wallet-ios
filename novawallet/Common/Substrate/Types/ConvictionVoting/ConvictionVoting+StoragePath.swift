import Foundation

extension ConvictionVoting {
    static var votingFor: StorageCodingPath {
        StorageCodingPath(moduleName: "ConvictionVoting", itemName: "VotingFor")
    }

    static var trackLocksFor: StorageCodingPath {
        StorageCodingPath(moduleName: "ConvictionVoting", itemName: "ClassLocksFor")
    }
}
