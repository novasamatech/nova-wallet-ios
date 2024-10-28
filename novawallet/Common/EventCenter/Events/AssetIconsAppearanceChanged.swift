import Foundation

struct AssetIconsAppearanceChanged: EventProtocol {
    let selectedAppearance: AppearanceIconsOptions

    func accept(visitor: EventVisitorProtocol) {
        visitor.processAssetIconsAppearanceChange(event: self)
    }
}
