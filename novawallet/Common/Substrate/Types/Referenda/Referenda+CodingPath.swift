import Foundation

extension Referenda {
    static var referendumInfo: StorageCodingPath {
        StorageCodingPath(moduleName: "Referenda", itemName: "ReferendumInfoFor")
    }

    static var trackQueue: StorageCodingPath {
        StorageCodingPath(moduleName: "Referenda", itemName: "TrackQueue")
    }

    static var tracks: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Referenda", constantName: "Tracks")
    }

    static var undecidingTimeout: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Referenda", constantName: "UndecidingTimeout")
    }
}
