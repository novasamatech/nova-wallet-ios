import Foundation

extension XcmUni {
    struct Versioned<Entity> {
        let entity: Entity
        let version: Xcm.Version
    }

    typealias VersionedMessage = Versioned<[XcmUni.Instruction]>
    typealias VersionedAsset = Versioned<XcmUni.Asset>
    typealias VersionedLocation = Versioned<XcmUni.RelativeLocation>
}

extension XcmUni.Versioned: Equatable where Entity: Equatable {}
