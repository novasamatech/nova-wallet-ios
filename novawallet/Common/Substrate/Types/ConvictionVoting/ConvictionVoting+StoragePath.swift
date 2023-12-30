import Foundation

extension ConvictionVoting {
    static var votingFor: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "VotingFor")
    }

    static var trackLocksFor: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "ClassLocksFor")
    }
}
