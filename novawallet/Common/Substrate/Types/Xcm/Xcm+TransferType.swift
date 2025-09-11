import Foundation
import SubstrateSdk

extension Xcm {
    enum GenericTransferType<Location> {
        case teleport
        case localReserve
        case destinationReserve
        case remoteReserve(Location)
    }

    typealias TransferType = GenericTransferType<XcmUni.VersionedLocation>
    typealias TransferTypeWithRelativeLocation = GenericTransferType<XcmUni.RelativeLocation>
}

extension Xcm.TransferType: Codable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case "Teleport":
            self = .teleport
        case "LocalReserve":
            self = .localReserve
        case "DestinationReserve":
            self = .destinationReserve
        case "RemoteReserve":
            let location = try container.decode(Location.self)
            self = .remoteReserve(location)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported transfer type \(type)"
                )
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .teleport:
            try container.encode("Teleport")
            try container.encode(JSON.null)
        case .localReserve:
            try container.encode("LocalReserve")
            try container.encode(JSON.null)
        case .destinationReserve:
            try container.encode("DestinationReserve")
            try container.encode(JSON.null)
        case let .remoteReserve(location):
            try container.encode("RemoteReserve")
            try container.encode(location)
        }
    }
}

extension Xcm.TransferType {
    init(
        transferTypeWithRelativeLocation: Xcm.TransferTypeWithRelativeLocation,
        version: Xcm.Version
    ) {
        switch transferTypeWithRelativeLocation {
        case .teleport:
            self = .teleport
        case .localReserve:
            self = .localReserve
        case .destinationReserve:
            self = .destinationReserve
        case let .remoteReserve(location):
            self = .remoteReserve(
                XcmUni.VersionedLocation(
                    entity: location,
                    version: version
                )
            )
        }
    }
}
