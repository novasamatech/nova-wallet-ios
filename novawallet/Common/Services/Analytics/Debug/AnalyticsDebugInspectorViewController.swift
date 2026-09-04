#if F_DEV

    import UIKit
    import Operation_iOS
    import Keystore_iOS
    import NovaAppAttest

    /// A deliberately plain `UIViewController`: a developer tool, not a VIPER module, and it
    /// never reaches Release. Titles and labels are literals, not localized keys.
    ///
    /// It composes the same public pieces production does rather than widening
    /// `AnalyticsServiceFacadeProtocol` with debug-only members.
    final class AnalyticsDebugInspectorViewController: UIViewController {
        private let facade: AnalyticsServiceFacadeProtocol
        private let eventQueue: AnalyticsEventQueueProtocol
        private let attestationMode: BackendAttestationMode
        private let settingsManager: SettingsManagerProtocol
        private let recorder: AnalyticsAttestationFixtureRecorder
        private let operationQueue: OperationQueue

        private let statusLabel = UILabel()

        init(
            facade: AnalyticsServiceFacadeProtocol,
            eventQueue: AnalyticsEventQueueProtocol,
            attestationMode: BackendAttestationMode,
            settingsManager: SettingsManagerProtocol,
            recorder: AnalyticsAttestationFixtureRecorder,
            operationQueue: OperationQueue
        ) {
            self.facade = facade
            self.eventQueue = eventQueue
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
        /// pull CoreData and settings imports into a file that ships.
        static func createDefault() -> AnalyticsDebugInspectorViewController {
            let repository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
                UserDataStorageFacade.shared.createRepository(
                    filter: nil,
                    sortDescriptors: [.analyticsEventsBySequence],
                    mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
                )

            let appAttest = AppAttestService()

            return AnalyticsDebugInspectorViewController(
                facade: AnalyticsFacadeFactory.createDefault(),
                eventQueue: CoreDataAnalyticsEventQueue(
                    repository: AnyDataProviderRepository(repository)
                ),
                attestationMode: BackendAttestationModeResolver.resolve(
                    isReleaseBuild: false,
                    isAppAttestSupported: appAttest.isSupported
                ),
                settingsManager: SettingsManager.shared,
                recorder: AnalyticsAttestationFixtureRecorder(
                    appAttest: appAttest,
                    remoteFactory: BackendAttestationRemoteFactory(
                        baseURL: ApplicationConfig.shared.gatewayURL
                    ),
                    identity: BackendAttestationIdentity(settingsManager: SettingsManager.shared),
                    operationQueue: OperationManagerFacade.sharedDefaultQueue
                ),
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
            let countOperation = eventQueue.countOperation()

            execute(
                operation: countOperation,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                guard let self else { return }

                let count = (try? result.get()).map(String.init) ?? "unknown"

                // Install id presence only — never the value, which is the pseudonymous
                // identifier the whole design keeps out of logs.
                statusLabel.text = [
                    "Queued events: \(count)",
                    "Consent: \(facade.consent.isEnabled ? "on" : "off")",
                    "Available: \(facade.consent.isAvailable)",
                    "Prompt seen: \(facade.consent.isPromptSeen)",
                    "Attestation mode: \(attestationMode)",
                    "Install id present: \(settingsManager.analyticsInstallId != nil)"
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
                operation: eventQueue.clearOperation(),
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        }

        @objc func actionEmit() {
            facade.track(.appOpened(isFirstLaunch: false))
            refresh()
        }

        @objc func actionRecordFixture() {
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
            guard
                let data = try? AnalyticsCoding.encoder.encode(fixture),
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
