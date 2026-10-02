import Foundation
import Operation_iOS

protocol SubtensorSubnetCatalogueServiceProtocol: AnyObject {
    func createCatalogueWrapper() -> CompoundOperationWrapper<SubtensorSubnetCatalogue>

    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue>
}
