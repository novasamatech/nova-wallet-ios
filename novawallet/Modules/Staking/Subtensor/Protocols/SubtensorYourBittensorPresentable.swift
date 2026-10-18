import UIKit

protocol SubtensorYourBittensorPresentable {
    func showYourBittensor(from view: ControllerBackedProtocol?, stakingOption: Multistaking.ChainAssetOption)
}

extension SubtensorYourBittensorPresentable {
    func presentYourBittensor(
        stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorStakingFlowStateProtocol
    ) {
        let tabBarController = UIApplication.shared.tabBarController
        let hostNavigation = tabBarController?.selectedViewController as? UINavigationController

        SubtensorModalStack.dismiss(above: tabBarController, animated: true) {
            guard let hostNavigation else {
                return
            }

            if let portfolio = hostNavigation.viewControllers.last(where: { $0 is SubtensorPortfolioViewController }) {
                hostNavigation.popToViewController(portfolio, animated: true)
            } else if let portfolioView = SubtensorPortfolioViewFactory.createView(
                for: stakingOption,
                flowState: flowState
            ) {
                hostNavigation.pushViewController(portfolioView.controller, animated: true)
            }
        }
    }
}
