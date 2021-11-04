import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import SubstrateSdk
import SoraKeystore
import SoraFoundation
import BigInt

class StakingRebondSetupTests: XCTestCase {

    func testRebondSetupAndAmountProvidingSuccess() throws {
        // given

        let view = MockStakingRebondSetupViewProtocol()
        let wireframe = MockStakingRebondSetupWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe)

        stub(view) { stub in
            when(stub).localizationManager.get.then { nil }

            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).proceed(view: any(), amount: any()).then { (view, amount) in
                completionExpectation.fulfill()
            }
        }

        presenter.updateAmount(0.01)
        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingRebondSetupViewProtocol,
        wireframe: MockStakingRebondSetupWireframeProtocol
    ) throws -> StakingRebondSetupPresenterProtocol {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)
        let selectedMetaAccount = AccountGenerator.generateMetaAccount()
        let managedMetaAccount = ManagedMetaAccountModel(info: selectedMetaAccount)
        let selectedAccount = selectedMetaAccount.fetch(for: chain.accountRequest())!

        let operationManager = OperationManager()

        let nominatorAddress = selectedAccount.toAddress()!

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
        let accountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // save controller
        let operationQueue = OperationQueue()
        let saveControllerOperation = accountRepository.saveOperation({ [managedMetaAccount] }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: selectedAccount.cryptoType)
        )

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress)
        let stakingLedger = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(3e+12),
            active: BigUInt(1e+12),
            unlocking: [
                UnlockChunk(value: BigUInt(2e+12), era: 5)
            ],
            claimedRewards: []
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: stakingLedger,
            activeEra: ActiveEraInfo(index: 1),
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+12)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: nil)
        )

        let interactor = StakingRebondSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let inputExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveAsset(viewModel: any()).then { viewModel in
                if let balance = viewModel.value(for: Locale.current).balance, !balance.isEmpty {
                    assetExpectation.fulfill()
                }
            }

            when(stub).didReceiveFee(viewModel: any()).then { viewModel in
                if let fee = viewModel?.value(for: Locale.current).amount, !fee.isEmpty {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceiveInput(viewModel: any()).then { _ in
                inputExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [inputExpectation, assetExpectation, feeExpectation], timeout: 10)

        return presenter
    }
}
