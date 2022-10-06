import Foundation

extension Referenda {
    static var referendumInfo: StorageCodingPath {
        StorageCodingPath(moduleName: "Referenda", itemName: "ReferendumInfoFor")
    }

    static var tracks: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Referenda", constantName: "Tracks")
    }
}
