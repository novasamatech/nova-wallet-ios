import Foundation

extension Referenda {
    static var referendumInfo: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "ReferendumInfoFor")
    }

    static var trackQueue: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "TrackQueue")
    }

    static var tracks: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "Tracks")
    }

    static var undecidingTimeout: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "UndecidingTimeout")
    }
}
