import Foundation

struct AssetVisibility {
    let defaults: DefaultAssetsList
    let rows: [ChainAssetId: AssetVisibilityState]

    func isVisible(_ id: ChainAssetId) -> Bool {
        if let state = rows[id] {
            return state == .visible
        }

        return defaults.isEmpty || defaults.contains(id)
    }
}
