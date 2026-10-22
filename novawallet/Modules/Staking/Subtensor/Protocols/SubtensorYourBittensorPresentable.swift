import UIKit
import NovaAnalytics

protocol SubtensorYourBittensorPresentable {
    func showYourBittensor(from view: ControllerBackedProtocol?, stakingOption: Multistaking.ChainAssetOption)
}

extension SubtensorYourBittensorPresentable {
    func presentYourBittensor(
        stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorFlowStateProtocol
    ) {
        let tabBarController = UIApplication.shared.tabBarController
        let hostNavigation = tabBarController?.selectedViewController as? UINavigationController

        SubtensorModalStack.dismiss(above: tabBarController, animated: true) {
            guard let hostNavigation else {
                return
            }

            if let portfolio = hostNavigation.viewControllers.last(where: { $0 is SubtensorPortfolioViewController }) {
                (portfolio as? SubtensorPortfolioViewController)?.presenter.reopen(from: .result)
                hostNavigation.popToViewController(portfolio, animated: true)
            } else if let portfolioView = SubtensorPortfolioViewFactory.createView(
                for: stakingOption,
                flowState: flowState,
                source: .result
            ) {
                hostNavigation.pushViewController(portfolioView.controller, animated: true)
            }
        }
    }
}
