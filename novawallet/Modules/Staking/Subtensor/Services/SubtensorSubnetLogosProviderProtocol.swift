import Foundation
import Operation_iOS

protocol SubtensorSubnetLogosProviderProtocol: AnyObject {
    func createLogosWrapper() -> CompoundOperationWrapper<SubtensorSubnetLogos>
}
