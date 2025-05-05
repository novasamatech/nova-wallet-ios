import Foundation

enum XcmTransferTypeError: Error {
    case unknownType
}

enum XcmTransferType: String, Decodable {
    case xtokens
    case xcmpallet
    case teleport = "xcmpallet-teleport"
    case xcmpalletTransferAssets = "xcmpallet-transferAssets"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let rawType = try container.decode(String.self)

        switch rawType {
        case Self.xtokens.rawValue:
            self = .xtokens
        case Self.xcmpallet.rawValue:
            self = .xcmpallet
        case Self.teleport.rawValue:
            self = .teleport
        case Self.xcmpalletTransferAssets.rawValue:
            self = .xcmpalletTransferAssets
        default:
            self = .unknown
        }
    }
}
