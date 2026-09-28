import Foundation
import Operation_iOS

protocol SubtensorSubnetCatalogueServiceProtocol: AnyObject {
    func createCatalogueWrapper(forcingRefresh: Bool) -> CompoundOperationWrapper<SubtensorSubnetCatalogue>
}
