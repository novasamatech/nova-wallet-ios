import Foundation

extension XcmUni {
    struct Versioned<Entity> {
        let entity: Entity
        let version: Xcm.Version
    }

    typealias VersionedMessage = Versioned<XcmUni.Instructions>
    typealias VersionedAsset = Versioned<XcmUni.Asset>
    typealias VersionedAssets = Versioned<XcmUni.Assets>
    typealias VersionedLocation = Versioned<XcmUni.RelativeLocation>
    typealias VersionedLocatableAsset = Versioned<XcmUni.LocatableAsset>
    typealias VersionedAssetId = Versioned<XcmUni.AssetId>
}

extension XcmUni.Versioned: Equatable where Entity: Equatable {}

protocol XcmUniVersioned {
    func versioned(_ version: Xcm.Version) -> XcmUni.Versioned<Self>
}

extension XcmUniVersioned {
    func versioned(_ version: Xcm.Version) -> XcmUni.Versioned<Self> {
        .init(entity: self, version: version)
    }
}

extension XcmUni.RelativeLocation: XcmUniVersioned {}
extension XcmUni.Asset: XcmUniVersioned {}
extension XcmUni.LocatableAsset: XcmUniVersioned {}

extension Array: XcmUniVersioned {}

extension XcmUni.VersionedAsset {
    func toVersionedAssets() -> XcmUni.VersionedAssets {
        [entity].versioned(version)
    }
}

extension XcmUni.Versioned {
    func map<U>(_ transformation: (Entity) throws -> U) rethrows -> XcmUni.Versioned<U> {
        let newEntity = try transformation(entity)
        return XcmUni.Versioned(entity: newEntity, version: version)
    }
}
