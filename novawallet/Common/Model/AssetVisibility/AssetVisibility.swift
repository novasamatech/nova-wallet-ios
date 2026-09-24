import Foundation

struct AssetVisibility {
    let defaults: DefaultAssetsList
    let rows: [ChainAssetId: AssetVisibilityState]

    func isVisible(_ id: ChainAssetId) -> Bool {
        AssetVisibilityPolicy.isVisible(
            state: rows[id],
            isDefault: defaults.isEmpty || defaults.contains(id)
        )
    }
}
