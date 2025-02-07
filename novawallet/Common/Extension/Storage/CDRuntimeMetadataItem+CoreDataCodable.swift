import Foundation
import Operation_iOS
import CoreData

extension CDRuntimeMetadataItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let item = try RuntimeMetadataItem(from: decoder)

        identifier = item.chain
        version = Int32(bitPattern: item.version)
        txVersion = Int32(bitPattern: item.txVersion)
        localMigratorVersion = Int32(bitPattern: item.localMigratorVersion)
        opaque = item.opaque
        metadata = item.metadata
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RuntimeMetadataItem.CodingKeys.self)

        try container.encode(identifier, forKey: .chain)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(UInt32(bitPattern: version), forKey: .version)
        try container.encode(UInt32(bitPattern: txVersion), forKey: .txVersion)
        try container.encode(UInt32(bitPattern: localMigratorVersion), forKey: .localMigratorVersion)
        try container.encode(opaque, forKey: .opaque)
    }
}
