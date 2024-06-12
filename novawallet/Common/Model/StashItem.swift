import Foundation
import Operation_iOS

struct StashItem: Codable, Equatable {
    let stash: String
    let controller: String
    let chainId: String
}

extension StashItem: Identifiable {
    var identifier: String {
        Self.createIdentifier(from: stash, chainId: chainId)
    }

    static func createIdentifier(from stash: String, chainId: ChainModel.Id) -> String {
        stash + "-" + chainId
    }
}
