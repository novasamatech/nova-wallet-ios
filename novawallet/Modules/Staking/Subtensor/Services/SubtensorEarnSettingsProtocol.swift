import Foundation

protocol SubtensorEarnSettingsProtocol: AnyObject {
    var slippageTolerance: BigRational { get set }
    var favouriteSubnets: [SubtensorSubnetRef] { get set }
    var lastStrategy: SubtensorStrategyKind? { get set }
}
