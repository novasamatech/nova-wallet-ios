import Foundation
import Foundation_iOS

final class OnboardingImportOptionsPresenter: WalletImportOptionsPresenter {
    let interactor: OnboardingImportOptionsInteractorInputProtocol
    let wireframe: OnboardingImportOptionsWireframeProtocol
    let logger: LoggerProtocol

    init(
        interactor: OnboardingImportOptionsInteractorInputProtocol,
        wireframe: OnboardingImportOptionsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init()

        self.localizationManager = localizationManager
    }

    // swiftlint:disable:next function_body_length
    override func provideViewModel() {
        let viewModel = WalletImportOptionViewModel(
            rows: [
                [
                    WalletImportOptionViewModel.RowItem.primary(
                        .init(
                            backgroundImage: R.image.bgCloudImport()!.resizableCenterImage(),
                            mainImage: R.image.iconCloudImport()!,
                            mainImagePosition: .center,
                            title: R.string.localizable.commonCloudBackup(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            subtitle: R.string.localizable.cloudImportDescription(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                self?.view?.didStartLoading()
                                self?.interactor.checkExistingBackup()
                            }
                        )
                    )
                ],
                [
                    WalletImportOptionViewModel.RowItem.primary(
                        .init(
                            backgroundImage: R.image.bgMnemonicImport()!.resizableCenterImage(),
                            mainImage: R.image.iconMnemonicImportRight()!,
                            mainImagePosition: .right,
                            title: R.string.localizable.commonPassphrase(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            subtitle: R.string.localizable.passphraseImportDescription(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                self?.wireframe.showPassphraseImport(from: self?.view)
                            }
                        )
                    ),
                    WalletImportOptionViewModel.RowItem.primary(
                        .init(
                            backgroundImage: R.image.bgHardwareWalletImport()!.resizableCenterImage(),
                            mainImage: R.image.iconHardwareWalletImport()!,
                            mainImagePosition: .center,
                            title: R.string.localizable.commonHardwareWallet(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            subtitle: R.string.localizable.hardwareWalletImportDescription(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                guard let self else {
                                    return
                                }

                                self.wireframe.showHardwareImport(from: self.view, locale: self.selectedLocale)
                            }
                        )
                    )
                ],
                [
                    WalletImportOptionViewModel.RowItem.primary(
                        .init(
                            backgroundImage: R.image.bgTrustWalletImport()!.resizableCenterImage(),
                            mainImage: R.image.iconTrustWalletImport()!,
                            mainImagePosition: .center,
                            title: R.string.localizable.commonTrustWallet(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            subtitle: R.string.localizable.trustWalletImportDescription(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                self?.wireframe.showTrustWalletImport(from: self?.view)
                            }
                        )
                    ),
                    WalletImportOptionViewModel.RowItem.primary(
                        .init(
                            backgroundImage: R.image.bgWatchOnlyImport()!.resizableCenterImage(),
                            mainImage: R.image.iconWatchOnlyImport()!,
                            mainImagePosition: .center,
                            title: R.string.localizable.commonWatchOnly(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            subtitle: R.string.localizable.createWatchOnlyDetails(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                self?.wireframe.showWatchOnlyImport(from: self?.view)
                            }
                        )
                    )
                ],
                [
                    WalletImportOptionViewModel.RowItem.secondary(
                        .init(
                            image: R.image.iconSeed()!,
                            title: R.string.localizable.importRawSeed(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                self?.wireframe.showSeedImport(from: self?.view)
                            }
                        )
                    ),
                    WalletImportOptionViewModel.RowItem.secondary(
                        .init(
                            image: R.image.iconRestoreJson()!,
                            title: R.string.localizable.importRecoveryJson(
                                preferredLanguages: selectedLocale.rLanguages
                            ),
                            onAction: { [weak self] in
                                self?.wireframe.showRestoreJsonImport(from: self?.view)
                            }
                        )
                    )
                ]
            ]
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension OnboardingImportOptionsPresenter: OnboardingImportOptionsInteractorOutputProtocol {
    func didReceive(backupExists: Bool) {
        logger.debug("Backup exists: \(backupExists)")

        view?.didStopLoading()

        if backupExists {
            wireframe.showCloudImport(from: view)
        } else if let view {
            wireframe.presentBackupNotFound(from: view, locale: selectedLocale)
        }
    }

    func didReceive(error: OnboardingImportOptionsInteractorError) {
        logger.error("Error: \(error)")

        guard let view else {
            return
        }

        view.didStopLoading()

        switch error {
        case .cloudNotAvailable:
            wireframe.presentCloudBackupUnavailable(from: view, locale: selectedLocale)
        case .serviceInternal:
            wireframe.presentNoCloudConnection(from: view, locale: selectedLocale)
        }
    }
}

extension OnboardingImportOptionsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
