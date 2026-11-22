import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

protocol RuntimeContainerSourceProtocol {
    var opaque: Bool { get }
    var metadata: Data { get }
}

extension RuntimeContainerSourceProtocol {
    /// The version the metadata declares in its header, read without parsing the metadata.
    /// Nil when the opaque value is `None`: the runtime doesn't have the version it was asked for.
    func readMetadataVersion() throws -> UInt8? {
        let decoder = try ScaleDecoder(data: metadata)

        if opaque {
            guard try Bool(scaleDecoder: decoder) else {
                return nil
            }

            let metadataLength = try BigUInt(scaleDecoder: decoder)

            guard metadataLength <= decoder.remained else {
                throw RuntimeMetadataContainerError.invalidMetadataLength
            }
        }

        // the version follows the magic number
        _ = try UInt32(scaleDecoder: decoder)

        return try UInt8(scaleDecoder: decoder)
    }
}

struct RuntimeMetadataItem: Codable & Equatable, RuntimeContainerSourceProtocol {
    enum CodingKeys: String, CodingKey {
        case chain
        case version
        case txVersion
        case localMigratorVersion
        case opaque
        case metadata
    }

    let chain: String
    let version: UInt32
    let txVersion: UInt32
    let localMigratorVersion: UInt32
    let opaque: Bool
    let metadata: Data
}

extension RuntimeMetadataItem: Identifiable {
    var identifier: String { chain }
}
