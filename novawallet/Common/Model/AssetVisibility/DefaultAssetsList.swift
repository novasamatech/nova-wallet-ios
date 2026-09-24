import Foundation

struct DefaultAssetRemote: Decodable {
    let chainId: String
    let assetId: AssetModel.Id
}

struct DefaultAssetsRemote: Decodable {
    static let supportedVersion: UInt = 1

    let version: UInt?
    let defaultAssets: [DefaultAssetRemote]

    var effectiveVersion: UInt {
        version ?? Self.supportedVersion
    }
}

struct DefaultAssetsList: Equatable {
    static let empty = DefaultAssetsList(ids: [])

    let ids: [ChainAssetId]
    let rank: [ChainAssetId: Int]

    var isEmpty: Bool {
        ids.isEmpty
    }

    init(ids: [ChainAssetId]) {
        self.ids = ids

        rank = ids.enumerated().reduce(into: [:]) { accum, item in
            guard accum[item.element] == nil else {
                return
            }

            accum[item.element] = item.offset
        }
    }

    init(remote: DefaultAssetsRemote) {
        let ids = remote.defaultAssets.map {
            ChainAssetId(chainId: $0.chainId, assetId: $0.assetId)
        }

        self.init(ids: ids)
    }

    func contains(_ id: ChainAssetId) -> Bool {
        rank[id] != nil
    }

    func rank(of id: ChainAssetId) -> Int? {
        rank[id]
    }
}
