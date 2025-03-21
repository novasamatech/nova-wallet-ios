import Foundation

protocol OnRampFlowManaging: BaseRampFlowManaging {}

extension OnRampFlowManaging where Self: RampDelegate {
    func startOnRampFlow(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        wireframe: (RampPresentable & AlertPresentable)?,
        assetSymbol: AssetModel.Symbol,
        locale: Locale
    ) {
        guard !actions.isEmpty else {
            return
        }
        if actions.count == 1 {
            startFlow(
                from: view,
                action: actions[0],
                wireframe: wireframe,
                locale: locale
            )
        } else {
            wireframe?.showOnRampProviders(
                from: view,
                actions: actions,
                assetSymbol: assetSymbol,
                delegate: self
            )
        }
    }
}
