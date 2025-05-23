import Foundation

final class StakingInternalLinkFactory: BaseInternalLinkFactory {}

extension StakingInternalLinkFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLink.Params) -> URL? {
        guard
            let action = externalParams[ExternalUniversalLink.actionKey] as? String,
            action == UniversalLink.Action.open.rawValue,
            let screen = externalParams[ExternalUniversalLink.screenKey] as? String,
            screen == UniversalLink.Screen.staking.rawValue else {
            return nil
        }

        return baseUrl
            .appendingPathComponent(UniversalLink.Action.open.rawValue)
            .appendingPathComponent(UniversalLink.Screen.staking.rawValue)
    }
}
