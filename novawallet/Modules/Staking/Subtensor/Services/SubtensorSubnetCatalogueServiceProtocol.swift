import Foundation
import Operation_iOS
import NovaAuth

protocol SubtensorSubnetCatalogueServiceProtocol: AnyObject {
    func createCatalogueWrapper(intent: NovaAuthRequestIntent) -> CompoundOperationWrapper<SubtensorSubnetCatalogue>

    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue>
}

extension SubtensorSubnetCatalogueServiceProtocol {
    func createCatalogueWrapper() -> CompoundOperationWrapper<SubtensorSubnetCatalogue> {
        createCatalogueWrapper(intent: .background)
    }
}
