import Foundation
import Foundation_iOS
import Keystore_iOS

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?
    var interactor: MainTabBarInteractorInputProtocol!
    var wireframe: MainTabBarWireframeProtocol!
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func viewDidAppear() {}

    func activateStatusAction() {
        wireframe.presentCloudBackupSettings(from: view)
    }

    func presentStatusAlert(_ closure: FlowStatusPresentingClosure) {
        closure(wireframe, view)
    }

    func presentDelayedOperationCreated() {
        wireframe.presentDelayedOperationCreated(from: view)
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didRequestAHMInfoOpen(with info: [AHMRemoteData]) {
        wireframe.presentAssetHubMigrationInfoScreen(
            in: view,
            with: info
        )
    }

    func didRequestMultisigNotificationsPromoOpen(with params: MultisigNotificationsPromoParams) {
        wireframe.presentMultisigNotificationsPromo(
            from: view,
            with: params
        )
    }

    func didRequestImportAccount(source: SecretSource) {
        wireframe.presentAccountImport(on: view, source: source)
    }

    func didRequestWalletMigration(with message: WalletMigrationMessage.Start) {
        wireframe.presentWalletMigration(on: view, message: message)
    }

    func didRequestScreenOpen(_ screen: UrlHandlingScreen) {
        wireframe.presentScreenIfNeeded(
            on: view,
            screen: screen,
            locale: localizationManager.selectedLocale
        )
    }

    func didRequestPushScreenOpen(_ screen: PushNotification.OpenScreen) {
        wireframe.presentScreenIfNeeded(
            on: view,
            screen: screen,
            locale: localizationManager.selectedLocale
        )
    }

    func didRequestReviewCloud(changes _: CloudBackupSyncResult.Changes) {
        wireframe.presentCloudBackupUnsyncedChanges(from: view) { [weak self] in
            self?.wireframe.presentCloudBackupSettings(from: self?.view)
        }
    }

    func didFoundCloudBackup(issue _: CloudBackupSyncResult.Issue) {
        wireframe.presentCloudBackupUpdateFailedIfNeeded(from: view) { [weak self] in
            self?.wireframe.presentCloudBackupSettings(from: self?.view)
        }
    }

    func didSyncCloudBackup(on purpose: CloudBackupSynсPurpose) {
        switch purpose {
        case .addChainAccount:
            wireframe.presentMultilineSuccessNotification(
                R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.commonAccountHasChanged(),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .createWallet:
            wireframe.presentMultilineSuccessNotification(
                R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.commonWalletCreated(),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .importWallet:
            wireframe.presentMultilineSuccessNotification(
                R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.commonWalletImported(),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .removeWallet:
            wireframe.presentMultilineSuccessNotification(
                R.string(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).localizable.commonWalletRemoved(),
                from: view?.controller.topModalViewController,
                completion: nil
            )
        case .unknown:
            break
        }
    }

    func didRequestPushNotificationsSetupOpen() {
        wireframe.presentPushNotificationsSetup(
            on: view,
            presentationCompletion: { [weak self] in
                self?.interactor.setPushNotificationsSetupScreenSeen()
            },
            flowCompletion: { [weak self] _ in
                self?.interactor.requestNextOnLaunchAction()
            }
        )
    }

    func showAnalyticsConsentOrNext() {
        let settings = SettingsManager.shared

        guard !settings.hasSeenAnalyticsPrompt else {
            interactor.requestNextOnLaunchAction()
            return
        }

        let title = R.string.localizable.analyticsConsentTitle(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let body = R.string.localizable.analyticsConsentBody(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let bullet1 = R.string.localizable.analyticsConsentBullet1(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let bullet2 = R.string.localizable.analyticsConsentBullet2(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let bullet3 = R.string.localizable.analyticsConsentBullet3(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let enableTitle = R.string.localizable.analyticsConsentEnable(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let laterTitle = R.string.localizable.analyticsConsentLater(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        let message = "\(body)\n\n• \(bullet1)\n• \(bullet2)\n• \(bullet3)"

        let enableAction = AlertPresentableAction(title: enableTitle, style: .normal) { [weak self] in
            settings.hasSeenAnalyticsPrompt = true
            settings.analyticsEnabled = true
            PostHogAnalyticsService.shared.isEnabled = true
            PostHogAnalyticsService.shared.track(.appOpened(isFirstLaunch: true))
            self?.interactor.requestNextOnLaunchAction()
        }

        let laterAction = AlertPresentableAction(title: laterTitle, style: .cancel) { [weak self] in
            settings.hasSeenAnalyticsPrompt = true
            self?.interactor.requestNextOnLaunchAction()
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [enableAction, laterAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    func didReceiveCloudSync(status: CloudBackupSyncMonitorStatus?) {
        switch status {
        case .noFile, .synced:
            view?.setSyncStatus(.synced)
        case .notDownloaded, .downloading, .uploading:
            view?.setSyncStatus(.syncing)
        case nil:
            view?.setSyncStatus(.disabled)
        }
    }
}
