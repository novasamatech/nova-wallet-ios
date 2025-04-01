import XCTest
@testable import novawallet
import BigInt
import Cuckoo
import Foundation_iOS
import Keystore_iOS

class AssetSelectionTests: XCTestCase {
    func testSuccessfullSelection() {
        // given

        let selectedAccount = AccountGenerator.generateMetaAccount()

        let assetsPerChain = 2
        let chains = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: assetsPerChain,
                addressPrefix: ChainModel.AddressPrefix(index),
                hasStaking: true
            )
        }

        let view = MockChainAssetSelectionViewProtocol()
        let wireframe = MockChainAssetSelectionWireframeProtocol()

        let storageFacade = SubstrateStorageTestFacade()
        let repository = ChainRepositoryFactory(storageFacade: storageFacade).createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let operationQueue = OperationQueue()

        let saveChainsOperation = repository.saveOperation( { chains }, { [] })
        operationQueue.addOperations([saveChainsOperation], waitUntilFinished: true)

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+18)
        )

        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "1.5",
                dayChange: nil,
                currencyId: Currency.usd.id
            )
        )

        let interactor = ChainAssetSelectionInteractor(
            selectedMetaAccount: selectedAccount,
            repository: repository,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceProviderFactory,
            assetFilter: { $0.asset.hasStaking },
            currencyManager: CurrencyManagerStub(),
            operationQueue: operationQueue
        )

        let selectedChain = chains.last!
        let selectedAsset = selectedChain.assets.first!
        let selectedChainAssetId = ChainAssetId(
            chainId: selectedChain.chainId,
            assetId: selectedAsset.assetId
        )

        let presenter = ChainAssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainAssetId: selectedChainAssetId,
            balanceMapper: AvailableBalanceSliceMapper(balanceSlice: \.transferable),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let loadingExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)
            stub.didReload().then {
                if presenter.numberOfItems == assetsPerChain * chains.count {
                    loadingExpectation.fulfill()
                }
            }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.complete(on: any(), selecting: any()).then { (_, chainAsset) in
                XCTAssertTrue(chainAsset.asset.hasStaking)
                completionExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [loadingExpectation], timeout: 10)

        // when

        presenter.selectItem(at: 0)

        // then

        wait(for: [completionExpectation], timeout: 10)
    }
}
