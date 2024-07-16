import Foundation
import Operation_iOS

protocol RuntimeContainerSourceProtocol {
    var opaque: Bool { get }
    var metadata: Data { get }
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
