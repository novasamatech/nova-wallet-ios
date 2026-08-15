import Foundation

extension MainTabBarInteractor {
    func openPendingScreenIfNeeded() -> Bool {
        if
            let message = walletMigrationService.consumePendingMessage(),
            case let .start(content) = message {
            presenter?.didRequestWalletMigration(with: content)
        } else if let pendingScreen = screenOpenService.consumePendingScreenOpen() {
            presenter?.didRequestScreenOpen(pendingScreen)
        } else if let pushPendingScreen = pushScreenOpenService.consumePendingScreenOpen() {
            presenter?.didRequestPushScreenOpen(pushPendingScreen)
        } else {
            return false
        }

        return true
    }

    func startLaunchQueue(openedPendingScreen: Bool) {
        let promptActions: [OnLaunchActionProtocol] = [
            OnLaunchAction.PushNotificationsSetup(),
            OnLaunchAction.AHMInfoSetup(),
            OnLaunchAction.MultisigNotificationsPromo()
        ]

        onLaunchQueue = OnLaunchActionsQueue(
            possibleActions: [OnLaunchAction.LegalConsent()] + (openedPendingScreen ? [] : promptActions)
        )
        onLaunchQueue.delegate = self

        onLaunchQueue.runNext()
    }

    func showAhmInfoOrNext(nextOnLaunchClosure: (() -> Void)? = nil) {
        let wrapper = preSyncServiceCoodrinator.ahmInfoService.fetchPassedMigrationsInfo()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                guard !info.isEmpty else {
                    nextOnLaunchClosure?()
                    return
                }
                self?.presenter?.didRequestAHMInfoOpen(with: info)
            case let .failure(error):
                self?.logger.error("Error fetching AHM info: \(error)")
            }

            nextOnLaunchClosure?()
        }
    }
}

// MARK: - Private

private extension MainTabBarInteractor {
    func showLegalConsentOrNextAction() {
        guard walletSettings.hasValue else {
            onLaunchQueue.runNext()
            return
        }

        let wrapper = legalConsentRepository.consentRequiredWrapper()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            guard case let .success(required) = result, required else {
                onLaunchQueue.runNext()
                return
            }

            securedLayer.scheduleExecution { [weak self] isAuthorized in
                guard let self else { return }

                guard isAuthorized else {
                    onLaunchQueue.runNext()
                    return
                }

                presenter?.didRequestLegalConsentOpen()
            }
        }
    }

    func showPushNotificationsSetupOrNextAction() {
        if !settingsManager.notificationsSetupSeen {
            securedLayer.scheduleExecutionIfAuthorized { [weak self] in
                self?.presenter?.didRequestPushNotificationsSetupOpen()
            }
        } else {
            onLaunchQueue.runNext()
        }
    }

    func showAhmInfoOrNextAction() {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.showAhmInfoOrNext { self?.onLaunchQueue.runNext() }
        }
    }

    func setupNotificationPromoObserver() {
        notificationsPromoService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            guard let newState, case let .requestingShow(params) = newState else {
                return
            }

            self?.presenter?.didRequestMultisigNotificationsPromoOpen(with: params)
        }
    }

    func setupMultisigNotificationPromoOrNextAction() {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            self?.setupNotificationPromoObserver()
            self?.onLaunchQueue.runNext()
        }
    }
}

// MARK: - OnLaunchActionsQueueDelegate

extension MainTabBarInteractor: OnLaunchActionsQueueDelegate {
    func onLaunchProcessLegalConsent(_: OnLaunchAction.LegalConsent) {
        showLegalConsentOrNextAction()
    }

    func onLaunchProccessPushNotificationsSetup(_: OnLaunchAction.PushNotificationsSetup) {
        showPushNotificationsSetupOrNextAction()
    }

    func onLaunchProcessMultisigNotificationPromo(_: OnLaunchAction.MultisigNotificationsPromo) {
        setupMultisigNotificationPromoOrNextAction()
    }

    func onLaunchProcessAHMInfoSetup(_: OnLaunchAction.AHMInfoSetup) {
        showAhmInfoOrNextAction()
    }
}
