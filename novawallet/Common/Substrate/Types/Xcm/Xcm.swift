import Foundation

enum Xcm {
    // swiftlint:disable identifier_name
    enum Version: UInt8, Comparable {
        case V0
        case V1
        case V2
        case V3

        init?(rawName: String) {
            switch rawName {
            case "V0":
                self = .V0
            case "V1":
                self = .V1
            case "V2":
                self = .V2
            case "V3":
                self = .V3
            default:
                return nil
            }
        }

        static func < (lhs: Xcm.Version, rhs: Xcm.Version) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    // swiftlint:enable identifier_name
}
