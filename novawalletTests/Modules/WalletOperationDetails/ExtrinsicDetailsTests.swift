import XCTest
@testable import novawallet

import Foundation_iOS
import Cuckoo

class OperationDetailsTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockOperationDetailsViewProtocol()
        let wireframe = MockOperationDetailsWireframeProtocol()

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let chainAsset = ChainAsset(chain: chain, asset: chain.utilityAssets().first!)
        let wallet = AccountGenerator.generateMetaAccount()
        let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest())!
        let txData = AssetTransactionGenerator.generateExtrinsic(
            for: wallet,
            chainAsset: chainAsset
        )

        let userDataStorageFacade = UserDataStorageTestFacade()
        let substrateDataStorageFacade = SubstrateStorageTestFacade()

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: userDataStorageFacade
        )

        let operationQueue = OperationQueue()
        let transactionLocalSubscriptionFactory = TransactionLocalSubscriptionFactory(
            storageFacade: substrateDataStorageFacade,
            operationQueue: operationQueue,
            logger: nil
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: nil,
                currencyId: Currency.usd.id
            )
        )

        let operationDetailsProviderFactory = OperationDetailsDataProviderFactory(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: MockChainRegistryProtocol(),
            accountRepositoryFactory: accountRepositoryFactory,
            operationQueue: operationQueue
        )

        let operationDataProvider = operationDetailsProviderFactory.createProvider(for: txData)!

        let interactor = OperationDetailsInteractor(
            transaction: txData,
            chainAsset: chainAsset,
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            currencyManager: CurrencyManagerStub(),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationDataProvider: operationDataProvider
        )

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let viewModelFactory = OperationDetailsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
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
            when(stub.isSetup.get).thenReturn(false, true)

            when(stub.didReceive(viewModel: any())).then { _ in
                expectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [expectation], timeout: 10.0)

        XCTAssertNotNil(presenter.model)
    }
}
