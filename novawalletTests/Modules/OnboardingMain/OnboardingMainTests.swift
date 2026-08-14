import XCTest
@testable import novawallet
import SubstrateSdk
import Cuckoo
import Foundation_iOS

class OnboardingMainTests: XCTestCase {
    let dummyLegalData = LegalData(
        termsUrl: URL(string: "https://google.com")!,
        privacyPolicyUrl: URL(string: "https://github.com")!
    )

    func testSignup() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()
        let legalConsentRepository = MockLegalConsentRepositoryProtocol()

        let presenter = setupPresenterForWireframe(
            wireframe,
            view: view,
            legal: dummyLegalData,
            legalConsentRepository: legalConsentRepository
        )

        // when

        presenter.setup()
        presenter.toggleConsent()
        presenter.activateSignup()

        // then

        verify(wireframe, times(1)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
        verify(legalConsentRepository, times(1)).acceptCurrentVersions(deferringWhenUnavailable: any())
    }

    func testAccountRestore() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.toggleConsent()
        presenter.activateAccountRestore()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(1)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testActionsBlockedUntilConsent() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateSignup()
        presenter.activateAccountRestore()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
    }

    func testConsentResetsOnReappear() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.toggleConsent()
        presenter.viewWillAppear()
        presenter.activateSignup()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
    }

    func testTermsAndConditions() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateLegalDocument(.termsOfService)

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(
            url: ParameterMatcher { $0 == self.dummyLegalData.termsUrl },
            from: any(),
            style: any()
        )
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testPrivacyPolicy() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateLegalDocument(.privacyNotice)

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(
            url: ParameterMatcher { $0 == self.dummyLegalData.privacyPolicyUrl },
            from: any(),
            style: any()
        )
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testKeystoreImportSuggestion() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let secretImportService = SecretImportService(logger: Logger.shared)

        let presenter = setupPresenterForWireframe(
            wireframe,
            view: view,
            legal: dummyLegalData,
            secretImportService: secretImportService
        )

        // when

        presenter.setup()

        XCTAssertTrue(secretImportService.handle(url: KeystoreDefinition.validURL))

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(
            url: any(),
            from: any(),
            style: any()
        )
        verify(wireframe, times(1)).showAccountSecretImport(from: any(), source: any())
    }

    // MARK: Private

    private func setupPresenterForWireframe(
        _ wireframe: MockOnboardingMainWireframeProtocol,
        view: MockOnboardingMainViewProtocol,
        legal: LegalData,
        legalConsentRepository: MockLegalConsentRepositoryProtocol = MockLegalConsentRepositoryProtocol(),
        secretImportService: SecretImportServiceProtocol = SecretImportService(logger: Logger.shared),
        migrationService: WalletMigrationServiceProtocol = WalletMigrationService(
            localDeepLinkScheme: "novawallet",
            queryFactory: WalletMigrationQueryFactory()
        )
    )
        -> OnboardingMainPresenter {
        // The real interactor records consent on this mock from the deep link paths as well as
        // from `acceptLegalDocuments`, and an unstubbed Cuckoo mock raises a fatalError.
        stub(legalConsentRepository) { stub in
            when(stub.acceptCurrentVersions(deferringWhenUnavailable: any())).thenDoNothing()
        }

        let interactor = OnboardingMainInteractor(
            secretImportService: secretImportService,
            walletMigrationService: migrationService,
            legalConsentRepository: legalConsentRepository,
            walletSettings: SelectedWalletSettings(
                storageFacade: UserDataStorageTestFacade(),
                operationQueue: OperationQueue()
            )
        )

        let presenter = OnboardingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legal,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        interactor.presenter = presenter

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false, true)
            when(stub.didReceive(viewModel: any())).thenDoNothing()
            when(stub.didReceiveConsent(accepted: any())).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub.showAccountRestore(from: any())).thenDoNothing()
            when(stub.showSignup(from: any())).thenDoNothing()
            when(stub.showWeb(url: any(), from: any(), style: any())).thenDoNothing()
            when(stub.showAccountSecretImport(from: any(), source: any())).thenDoNothing()
            when(stub.showWalletMigration(from: any(), message: any())).thenDoNothing()
        }

        return presenter
    }
}
