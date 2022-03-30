import XCTest
@testable import novawallet
import CommonWallet
import SoraFoundation
import Cuckoo

class OperationDetailsTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockOperationDetailsViewProtocol()
        let wireframe = MockOperationDetailsWireframeProtocol()

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let chainAsset = ChainAsset(chain: chain, asset: chain.utilityAssets().first!)
        let wallet = AccountGenerator.generateMetaAccount()
        let txData = AssetTransactionGenerator.generateExtrinsic(
            for: wallet,
            chainAsset: chainAsset
        )

        let userDataStorageFacade = UserDataStorageTestFacade()
        let substrateDataStorageFacade = SubstrateStorageTestFacade()

        let walletRepository = AccountRepositoryFactory(
            storageFacade: userDataStorageFacade
        ).createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let operationQueue = OperationQueue()
        let transactionLocalSubscriptionFactory = TransactionLocalSubscriptionFactory(
            storageFacade: substrateDataStorageFacade,
            operationQueue: operationQueue,
            logger: nil
        )

        let interactor = OperationDetailsInteractor(
            txData: txData,
            chainAsset: chainAsset,
            wallet: wallet,
            walletRepository: walletRepository,
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            operationQueue: operationQueue
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo
        )

        let viewModelFactory = OperationDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            feeViewModelFactory: nil
        )

        let presenter = OperationDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).didReceive(viewModel: any()).then { viewModel in
                expectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [expectation], timeout: 10.0)

        XCTAssertNotNil(presenter.model)
    }
}
