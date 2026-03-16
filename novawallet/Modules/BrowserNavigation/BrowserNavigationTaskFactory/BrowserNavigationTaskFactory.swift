import Foundation
import UIKit
import UIKit_iOS

protocol BrowserNavigationTaskFactoryProtocol {
    func createDAppNavigationTaskById(
        _ dAppId: String,
        wallet: MetaAccountModel?,
        favoritesProvider: @escaping () -> [String: DAppFavorite]?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask

    func createDAppNavigationTaskByModel(
        _ model: DAppNavigation,
        wallet: MetaAccountModel?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask

    func createSearchResultNavigationTask(
        _ result: DAppSearchResult,
        wallet: MetaAccountModel
    ) -> BrowserNavigationTask
}

final class BrowserNavigationTaskFactory {
    weak var mainAppContainer: NovaMainAppContainerViewProtocol?

    init(mainAppContainer: NovaMainAppContainerViewProtocol) {
        self.mainAppContainer = mainAppContainer
    }

    private func routeTab(_ tab: DAppBrowserTab) {
        guard let mainAppContainer else { return }

        if ThirdPartyStakingDomainMatcher.isBlocked(url: tab.url) {
            presentStakingWarning(for: tab.url, on: mainAppContainer)
        } else {
            mainAppContainer.openBrowser(with: tab)
        }
    }

    private func presentStakingWarning(
        for url: URL,
        on container: NovaMainAppContainerViewProtocol
    ) {
        let delegate = PreBrowserStakingWarningDelegate(
            url: url,
            container: container
        )

        guard let warningView = DAppStakingWarningViewFactory.createView(
            for: url,
            delegate: delegate
        ) else {
            return
        }

        // Keep a strong reference to the delegate until the warning is dismissed
        warningView.controller.stakingWarningDelegate = delegate

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.novaManual
        )
        warningView.controller.modalTransitioningFactory = factory
        warningView.controller.modalPresentationStyle = .custom

        container.controller.topModalViewController.present(
            warningView.controller,
            animated: true,
            completion: nil
        )
    }
}

// MARK: BrowserNavigationTaskFactoryProtocol

extension BrowserNavigationTaskFactory: BrowserNavigationTaskFactoryProtocol {
    func createDAppNavigationTaskById(
        _ dAppId: String,
        wallet: MetaAccountModel?,
        favoritesProvider: @escaping () -> [String: DAppFavorite]?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask {
        BrowserNavigationTask(
            tabProvider: {
                guard
                    let wallet,
                    case let .success(dAppList) = dAppResultProvider()
                else { return nil }

                let tab: DAppBrowserTab? = if let dApp = dAppList.dApps.first(where: { $0.identifier == dAppId }) {
                    DAppBrowserTab(from: dApp, metaId: wallet.metaId)
                } else if let dApp = favoritesProvider()?[dAppId] {
                    DAppBrowserTab(from: dApp.identifier, metaId: wallet.metaId)
                } else {
                    DAppBrowserTab(from: dAppId, metaId: wallet.metaId)
                }

                return tab
            },
            routingClosure: { [weak self] tab in
                self?.routeTab(tab)
            }
        )
    }

    func createDAppNavigationTaskByModel(
        _ model: DAppNavigation,
        wallet: MetaAccountModel?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask {
        BrowserNavigationTask(
            tabProvider: {
                guard
                    let wallet,
                    case let .success(dAppList) = dAppResultProvider(),
                    let dApp = dAppList.dApps.first(
                        where: { URL.hostsEqual($0.url, model.url) }
                    )
                else {
                    return nil
                }

                let searchResult: DAppSearchResult = if dApp.url == model.url {
                    .dApp(model: dApp)
                } else {
                    .query(string: model.url.absoluteString)
                }

                return DAppBrowserTab(from: searchResult, metaId: wallet.metaId)
            },
            routingClosure: { [weak self] tab in
                self?.routeTab(tab)
            }
        )
    }

    func createSearchResultNavigationTask(
        _ result: DAppSearchResult,
        wallet: MetaAccountModel
    ) -> BrowserNavigationTask {
        BrowserNavigationTask(
            tabProvider: {
                DAppBrowserTab(from: result, metaId: wallet.metaId)
            },
            routingClosure: { [weak self] tab in
                self?.routeTab(tab)
            }
        )
    }
}

// MARK: - PreBrowserStakingWarningDelegate

/// Handles the staking warning that appears BEFORE the browser opens.
/// When user navigates to a blocked staking domain, this delegate is used
/// to either open the browser (continue) or switch to the staking tab (go to stake).
final class PreBrowserStakingWarningDelegate: DAppStakingWarningViewDelegate {
    let url: URL
    weak var container: NovaMainAppContainerViewProtocol?

    init(url: URL, container: NovaMainAppContainerViewProtocol) {
        self.url = url
        self.container = container
    }

    func dappStakingWarningDidSelectGoToStake() {
        UIApplication.shared.rootContainer?.browserWidget?.closeBrowser()
        UIApplication.shared.tabBarController?.selectedIndex = MainTabBarIndex.staking
    }

    func dappStakingWarningDidSelectContinue(to url: URL) {
        guard let container else { return }

        let tab = DAppBrowserTab(
            uuid: UUID(),
            name: nil,
            url: url,
            metaId: SelectedWalletSettings.shared.value.metaId,
            createdAt: Date(),
            renderModifiedAt: nil,
            transportStates: nil,
            desktopOnly: nil,
            icon: nil
        )

        container.openBrowser(with: tab)
    }
}

// MARK: - Associated object for delegate retention

private var stakingWarningDelegateKey: UInt8 = 0

extension UIViewController {
    var stakingWarningDelegate: PreBrowserStakingWarningDelegate? {
        get {
            objc_getAssociatedObject(self, &stakingWarningDelegateKey) as? PreBrowserStakingWarningDelegate
        }
        set {
            objc_setAssociatedObject(self, &stakingWarningDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
