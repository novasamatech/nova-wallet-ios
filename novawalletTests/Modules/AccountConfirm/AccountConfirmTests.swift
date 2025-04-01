import XCTest
@testable import novawallet
import Keystore_iOS
import Foundation_iOS
import Cuckoo
import NovaCrypto
import Operation_iOS

class AccountConfirmTests: XCTestCase {

    func testMnemonicConfirm() throws {
        // given

        let view = MockAccountConfirmViewProtocol()
        let wireframe = MockAccountConfirmWireframeProtocol()

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
        let keychain = InMemoryKeychain()

        let mnemonicWords = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let newAccountRequest = MetaAccountCreationRequest(
            username: "myusername",
            derivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519
        )

        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicWords)

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)

        let repository = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = MockEventCenterProtocol()

        let interactor = AccountConfirmInteractor(request: newAccountRequest,
                                                  mnemonic: mnemonic,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(repository),
                                                  settings: settings,
                                                  operationManager: OperationManager(),
                                                  eventCenter: eventCenter)
        
        let localizationManager = LocalizationManager.shared
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)

        let presenter = AccountConfirmPresenter(
            wireframe: wireframe,
            interactor: interactor,
            mnemonicViewModelFactory: mnemonicViewModelFactory,
            localizationManager: localizationManager
        )
        presenter.view = view
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).update(
                with: any(),
                gridUnits: any(),
                afterConfirmationFail: any()
            ).then { _ in
                setupExpectation.fulfill()
            }
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).proceed(from: any()).then { _ in
                expectation.fulfill()
            }
        }

        let completeExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is SelectedWalletSwitched {
                    completeExpectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: 10)

        presenter.confirm(words: mnemonic.allWords())

        // then

        wait(for: [expectation, completeExpectation], timeout: 10)

        guard let selectedAccount = settings.value else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.name, newAccountRequest.username)

        let metaId = selectedAccount.metaId

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(metaId)))

        XCTAssertFalse(try keychain.checkKey(for: KeystoreTagV2.substrateDerivationTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSeedTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSeedTagForMetaId(metaId)))
    }
}
