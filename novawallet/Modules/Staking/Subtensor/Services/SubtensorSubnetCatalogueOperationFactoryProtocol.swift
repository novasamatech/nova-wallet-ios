import Foundation
import Operation_iOS

protocol SubtensorSubnetCatalogueOperationFactoryProtocol: AnyObject {
    func createCatalogueWrapper() -> CompoundOperationWrapper<SubtensorSubnetCatalogue>

    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue>
}
