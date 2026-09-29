import UIKit

protocol SubtensorYourBittensorPresentable {
    func showYourBittensor(from view: ControllerBackedProtocol?, stakingOption: Multistaking.ChainAssetOption)
}

extension SubtensorYourBittensorPresentable {
    func showYourBittensor(from _: ControllerBackedProtocol?, stakingOption: Multistaking.ChainAssetOption) {
        let hostNavigation = UIApplication.shared.tabBarController?.selectedViewController as? UINavigationController

        let landing = {
            guard let hostNavigation else {
                return
            }

            if let portfolio = hostNavigation.viewControllers.last(where: { $0 is SubtensorPortfolioViewController }) {
                hostNavigation.popToViewController(portfolio, animated: true)
            } else if let portfolioView = SubtensorPortfolioViewFactory.createView(for: stakingOption) {
                hostNavigation.pushViewController(portfolioView.controller, animated: true)
            }
        }

        if let rootContainer = UIApplication.shared.rootContainer, rootContainer.presentedViewController != nil {
            rootContainer.dismiss(animated: true, completion: landing)
        } else {
            landing()
        }
    }
}
