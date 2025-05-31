import XCTest
@testable import novawallet
import SubstrateSdk
import Cuckoo
import Foundation_iOS

class OnboardingMainTests: XCTestCase {

    let dummyLegalData = LegalData(termsUrl: URL(string: "https://google.com")!,
                                   privacyPolicyUrl: URL(string: "https://github.com")!)

    func testSignup() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateSignup()

        // then

        verify(wireframe, times(1)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testAccountRestore() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateAccountRestore()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(1)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(), from: any(), style: any())
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testTermsAndConditions() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activateTerms()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.dummyLegalData.termsUrl },
                                            from: any(),
                                            style: any())
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testPrivacyPolicy() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let presenter = setupPresenterForWireframe(wireframe, view: view, legal: dummyLegalData)

        // when

        presenter.setup()
        presenter.activatePrivacy()

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(1)).showWeb(url: ParameterMatcher { $0 == self.dummyLegalData.privacyPolicyUrl },
                                            from: any(),
                                            style: any())
        verify(wireframe, times(0)).showAccountSecretImport(from: any(), source: any())
    }

    func testKeystoreImportSuggestion() {
        // given

        let view = MockOnboardingMainViewProtocol()
        let wireframe = MockOnboardingMainWireframeProtocol()

        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let presenter = setupPresenterForWireframe(wireframe,
                                                   view: view,
                                                   legal: dummyLegalData,
                                                   keystoreImportService: keystoreImportService)

        // when

        presenter.setup()

        XCTAssertTrue(keystoreImportService.handle(url: KeystoreDefinition.validURL))

        // then

        verify(wireframe, times(0)).showSignup(from: any())
        verify(wireframe, times(0)).showAccountRestore(from: any())
        verify(wireframe, times(0)).showWeb(url: any(),
                                            from: any(),
                                            style: any())
        verify(wireframe, times(1)).showAccountSecretImport(from: any(), source: any())
    }

    // MARK: Private

    private func setupPresenterForWireframe(_ wireframe: MockOnboardingMainWireframeProtocol,
                                            view: MockOnboardingMainViewProtocol,
                                            legal: LegalData,
                                            keystoreImportService: KeystoreImportServiceProtocol = KeystoreImportService(logger: Logger.shared),
                                            migrationService: WalletMigrationServiceProtocol = WalletMigrationService(
                                                localDeepLinkScheme: "novawallet",
                                                queryFactory: WalletMigrationQueryFactory()
                                            )
    )
        -> OnboardingMainPresenter {
        let interactor = OnboardingMainInteractor(
            keystoreImportService: keystoreImportService,
            walletMigrationService: migrationService
        )

        let presenter = OnboardingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legal,
            locale: Locale.current
        )

        presenter.view = view

        interactor.presenter = presenter

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
        }

        stub(wireframe) { stub in
            when(stub).showAccountRestore(from: any()).thenDoNothing()
            when(stub).showSignup(from: any()).thenDoNothing()
            when(stub).showWeb(url: any(), from: any(), style: any()).thenDoNothing()
            when(stub).showAccountSecretImport(from: any(), source: any()).thenDoNothing()
            when(stub).showWalletMigration(from: any(), message: any()).thenDoNothing()
        }

        return presenter
    }
}
