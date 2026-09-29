import UIKit

protocol SubtensorYourBittensorPresentable {
    func showYourBittensor(from view: ControllerBackedProtocol?, stakingOption: Multistaking.ChainAssetOption)
}

extension SubtensorYourBittensorPresentable {
    func showYourBittensor(from _: ControllerBackedProtocol?, stakingOption: Multistaking.ChainAssetOption) {
        let tabBarController = UIApplication.shared.tabBarController
        let hostNavigation = tabBarController?.selectedViewController as? UINavigationController

        SubtensorModalStack.dismiss(above: tabBarController, animated: true) {
            guard let hostNavigation else {
                return
            }

            if let portfolio = hostNavigation.viewControllers.last(where: { $0 is SubtensorPortfolioViewController }) {
                hostNavigation.popToViewController(portfolio, animated: true)
            } else if let portfolioView = SubtensorPortfolioViewFactory.createView(for: stakingOption) {
                hostNavigation.pushViewController(portfolioView.controller, animated: true)
            }
        }
    }
}
