import Foundation

extension Democracy {
    static var referendumInfo: StorageCodingPath {
        StorageCodingPath(moduleName: "Democracy", itemName: "ReferendumInfoOf")
    }

    static var votingOf: StorageCodingPath {
        StorageCodingPath(moduleName: "Democracy", itemName: "VotingOf")
    }

    static var preimages: StorageCodingPath {
        StorageCodingPath(moduleName: "Democracy", itemName: "Preimages")
    }
}
