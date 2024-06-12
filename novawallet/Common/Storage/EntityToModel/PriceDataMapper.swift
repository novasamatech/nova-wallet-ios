import Foundation
import Operation_iOS
import CoreData
import BigInt

final class PriceDataMapper {
    var entityIdentifierFieldName: String { #keyPath(CDPrice.identifier) }

    typealias DataProviderModel = PriceData
    typealias CoreDataEntity = CDPrice
}

extension PriceDataMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        PriceData(
            identifier: entity.identifier!,
            price: entity.price!,
            dayChange: entity.dayChange?.decimalValue,
            currencyId: Int(entity.currency)
        )
    }

    func populate(entity: CoreDataEntity, from model: DataProviderModel, using _: NSManagedObjectContext) throws {
        entity.identifier = model.identifier
        entity.currency = Int16(model.currencyId!)
        entity.price = model.price
        entity.dayChange = model.dayChange.map { NSDecimalNumber(decimal: $0) }
    }
}
