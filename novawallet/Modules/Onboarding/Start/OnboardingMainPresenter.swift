import Foundation
import Foundation_iOS

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    let wireframe: OnboardingMainWireframeProtocol
    let interactor: OnboardingMainInteractorInputProtocol
    let analyticsService: AnalyticsServiceProtocol

    let legalData: LegalData
    let onboardingSource: OnboardingSource

    let locale: Locale

    init(
        interactor: OnboardingMainInteractorInputProtocol,
        wireframe: OnboardingMainWireframeProtocol,
        legalData: LegalData,
        onboardingSource: OnboardingSource = .freshInstall,
        analyticsService: AnalyticsServiceProtocol = PostHogAnalyticsService.shared,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.onboardingSource = onboardingSource
        self.analyticsService = analyticsService
        self.locale = locale
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        // Only track for add_wallet flow — fresh install can't fire (user hasn't consented to analytics yet)
        if onboardingSource == .addWallet {
            analyticsService.track(.onboardingStarted(source: onboardingSource))
        }
        interactor.setup()
    }

    func activateTerms() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.termsUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.privacyPolicyUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activateSignup() {
        analyticsService.track(.walletCreationMethodSelected(method: .create))
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        analyticsService.track(.walletCreationMethodSelected(method: .importMnemonic))
        wireframe.showAccountRestore(from: view)
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestSecretImport(source: SecretSource) {
        wireframe.showAccountSecretImport(from: view, source: source)
    }

    func didSuggestWalletMigration(with message: WalletMigrationMessage.Start) {
        wireframe.showWalletMigration(from: view, message: message)
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: locale)
    }
}
