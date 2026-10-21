import Foundation
import Operation_iOS

protocol SubtensorSubnetLogosProviderProtocol: AnyObject {
    func createLogosWrapper() -> CompoundOperationWrapper<SubtensorSubnetLogos>
}

protocol SubtensorConfigProviding: SubtensorSubnetLogosProviderProtocol {
    func createNovaFeeRateWrapper() -> CompoundOperationWrapper<BigRational>
}
