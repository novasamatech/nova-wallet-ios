#if F_DEV

    import UIKit
    import Operation_iOS
    import Keystore_iOS
    import NovaAppAttest
    import NovaAnalytics

    /// A deliberately plain `UIViewController`: a developer tool, not a VIPER module, and it
    /// never reaches Release. Titles and labels are literals, not localized keys.
    ///
    /// It reaches the pending queue through the two `AnalyticsDebugInspecting` accessors —
    /// a protocol separate from `AnalyticsServiceFacadeProtocol`, so nothing but this screen
    /// depends on them — rather than opening the analytics store itself. A second
    /// `NSPersistentStoreCoordinator` over the same sqlite would give this screen its own
    /// snapshot of a queue the facade is concurrently writing — and a stale count here reads
    /// as a queue bug.
    final class AnalyticsDebugInspectorViewController: UIViewController {
        /// Every row the peek is willing to return. The queue trims itself to 500, so a
        /// larger window is what lets an exact count be reported rather than a truncated
        /// one; `refresh()` still marks the result when it comes back full.
        private static let pendingEventLimit = 1000

        private let facade: AnalyticsServiceFacadeProtocol & AnalyticsDebugInspecting
        private let attestationMode: BackendAttestationMode
        private let settingsManager: SettingsManagerProtocol
        private let recorder: AnalyticsAttestationFixtureRecorder?
        private let operationQueue: OperationQueue

        private let statusLabel = UILabel()

        init(
            facade: AnalyticsServiceFacadeProtocol & AnalyticsDebugInspecting,
            attestationMode: BackendAttestationMode,
            settingsManager: SettingsManagerProtocol,
            recorder: AnalyticsAttestationFixtureRecorder?,
            operationQueue: OperationQueue
        ) {
            self.facade = facade
            self.attestationMode = attestationMode
            self.settingsManager = settingsManager
            self.recorder = recorder
            self.operationQueue = operationQueue

            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Composed here rather than in `SettingsWireframe` so a debug-only screen does not
        /// pull attestation and settings imports into a file that ships.
        static func createDefault() -> AnalyticsDebugInspectorViewController {
            let appAttest = AppAttestService()

            return AnalyticsDebugInspectorViewController(
                facade: AnalyticsFacadeFactory.createDefault(),
                attestationMode: BackendAttestationModeResolver.resolve(
                    isAppAttestSupported: appAttest.isSupported
                ),
                settingsManager: SettingsManager.shared,
                recorder: makeRecorder(appAttest: appAttest),
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        }

        /// Nil when the build carries no App ID prefix: without it the registration binding would
        /// name an app the gateway cannot match, so there is nothing worth recording.
        private static func makeRecorder(
            appAttest: AppAttestServiceProtocol
        ) -> AnalyticsAttestationFixtureRecorder? {
            let gatewayURL = ApplicationConfig.shared.gatewayURL

            guard
                let appIdentity = ApplicationConfig.shared.appAttestAppIdentity,
                let requestTarget = try? AnalyticsUploadOperationFactory(baseURL: gatewayURL).eventsTarget()
            else {
                return nil
            }

            return AnalyticsAttestationFixtureRecorder(
                appAttest: appAttest,
                remoteFactory: BackendAttestationRemoteFactory(baseURL: gatewayURL),
                identity: BackendAttestationIdentity(settingsManager: SettingsManager.shared),
                appIdentity: appIdentity,
                requestTarget: requestTarget,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            title = "Analytics Debug"
            view.backgroundColor = R.color.colorSecondaryScreenBackground()

            setupLayout()
            refresh()
        }
    }

    // MARK: - Private

    private extension AnalyticsDebugInspectorViewController {
        func setupLayout() {
            statusLabel.numberOfLines = 0
            statusLabel.font = .systemFont(ofSize: 13.0, weight: .regular)
            statusLabel.textColor = R.color.colorTextPrimary()

            let stack = UIStackView(
                arrangedSubviews: [statusLabel]
                    + [
                        ("Send one event now", #selector(actionSendOne)),
                        ("Erase client id and key", #selector(actionEraseIdentity)),
                        ("Flush now", #selector(actionFlush)),
                        ("Clear queue", #selector(actionClear)),
                        ("Emit sample event", #selector(actionEmit)),
                        ("Record attestation fixture", #selector(actionRecordFixture))
                    ].map(makeButton)
            )

            stack.axis = .vertical
            stack.spacing = 16.0
            stack.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
                stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
                stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16.0)
            ])
        }

        func makeButton(title: String, action: Selector) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.contentHorizontalAlignment = .leading
            button.addTarget(self, action: action, for: .touchUpInside)

            return button
        }

        func refresh() {
            execute(
                wrapper: facade.debugPendingEventsWrapper(count: Self.pendingEventLimit),
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                guard let self else { return }

                // A full window means the queue may hold more, so say so rather than
                // report the window size as the count.
                let count = (try? result.get()).map { events in
                    "\(events.count)" + (events.count < Self.pendingEventLimit ? "" : "+")
                } ?? "unknown"

                // Install id presence only — never the value, which is the pseudonymous
                // identifier the whole design keeps out of logs.
                statusLabel.text = [
                    "Queued events: \(count)",
                    "Consent: \(facade.consent.isEnabled ? "on" : "off")",
                    "Available: \(facade.consent.isAvailable)",
                    "Prompt seen: \(facade.consent.isPromptSeen)",
                    "Attestation mode: \(attestationMode)",
                    // The accessor is internal to NovaAnalytics, so this reads the raw key —
                    // exactly the raw value the package writes under.
                    "Install id present: \(settingsManager.string(for: "analyticsInstallId") != nil)"
                ].joined(separator: "\n")
            }
        }

        func present(message: String) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .cancel))

            present(alert, animated: true)
        }

        @objc func actionFlush() {
            facade.flush(reason: .manual)
            present(message: "Flush requested")
        }

        @objc func actionClear() {
            execute(
                operation: facade.debugClearPendingEventsOperation(),
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        }

        /// One event, delivered in the same chain, so a whole attestation round trip can be watched
        /// end to end. The queue is what reports the verdict: a delivered batch is deleted, while any
        /// refusal retains it — and the gateway's own code for that refusal is on the log line
        /// `Analytics delivery refused`.
        @objc func actionSendOne() {
            sendOneEvent(prefix: "Sent one event")
        }

        /// Erases the identity and stops there, leaving the install in the state a first run starts
        /// from. Nothing is re-registered here on purpose: relaunching and letting the launch flush
        /// drive it is what exercises a genuine cold run.
        @objc func actionEraseIdentity() {
            facade.debugResetAttestationIdentity()
            refresh()
            present(message: "Client id and key erased. Relaunch to watch a cold run.")
        }

        func sendOneEvent(prefix: String) {
            pendingCount { [weak self] before in
                guard let self else { return }

                facade.trackAndFlush(.appOpened(isFirstLaunch: false), reason: .manual) { [weak self] in
                    guard let self else { return }

                    pendingCount { [weak self] after in
                        guard let self else { return }

                        let verdict = after < before + 1
                            ? "delivered (queue \(before) -> \(after))"
                            : "retained (queue \(before) -> \(after)) — see the log for the gateway code"

                        present(message: "\(prefix): \(verdict)")
                        refresh()
                    }
                }
            }
        }

        /// The queue depth, or the window size when the peek comes back full; a failed read reports
        /// zero so the verdict degrades to "retained" rather than claiming a delivery.
        func pendingCount(_ completion: @escaping (Int) -> Void) {
            execute(
                wrapper: facade.debugPendingEventsWrapper(count: Self.pendingEventLimit),
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                completion((try? result.get())?.count ?? 0)
            }
        }

        @objc func actionEmit() {
            facade.track(.appOpened(isFirstLaunch: false))
            refresh()
        }

        @objc func actionRecordFixture() {
            guard let recorder else {
                return present(message: "No App ID prefix in this build; a fixture cannot be recorded")
            }

            execute(
                wrapper: recorder.recordWrapper(),
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                guard let self else { return }

                switch result {
                case let .success(fixture):
                    share(fixture: fixture)
                case let .failure(error):
                    present(message: "Fixture failed: \(error)")
                }
            }
        }

        func share(fixture: AnalyticsAttestationFixture) {
            // A local encoder rather than the package's `AnalyticsCoding`, which is
            // internal to NovaAnalytics: this encodes an app-side fixture, not a wire
            // envelope. `.sortedKeys` only, so the recorded sample stays reproducible.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]

            guard
                let data = try? encoder.encode(fixture),
                let json = String(data: data, encoding: .utf8)
            else {
                present(message: "Fixture could not be encoded")
                return
            }

            let controller = UIActivityViewController(activityItems: [json], applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = view

            present(controller, animated: true)
        }
    }

#endif
