import Foundation

protocol SubtensorEarnSettingsProtocol: AnyObject {
    var slippageTolerance: BigRational { get set }
    var favouriteSubnets: Set<SubtensorSubnetRef> { get set }
}
