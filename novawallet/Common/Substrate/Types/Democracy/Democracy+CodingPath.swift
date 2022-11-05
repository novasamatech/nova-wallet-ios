import Foundation

extension Democracy {
    static var referendumInfo: StorageCodingPath {
        StorageCodingPath(moduleName: "Democracy", itemName: "ReferendumInfoFor")
    }

    static var votingOf: StorageCodingPath {
        StorageCodingPath(moduleName: "Democracy", itemName: "VotingOf")
    }
}
