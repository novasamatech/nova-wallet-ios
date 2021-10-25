import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation
import BigInt

class StakingUnbondSetupTests: XCTestCase {

    func testUnbondingSetupAndAmountProvidingSuccess() throws {
        // given

        let view = MockStakingUnbondSetupViewProtocol()
        let wireframe = MockStakingUnbondSetupWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe)

        let inputViewModelReloaded = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveInput(viewModel: any()).then { viewModel in
                inputViewModelReloaded.fulfill()
            }

            when(stub).localizationManager.get.then { nil }

            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
            when(stub).didReceiveBonding(duration: any()).thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).proceed(view: any(), amount: any()).then { (view, amount) in
                completionExpectation.fulfill()
            }
        }

        presenter.selectAmountPercentage(0.75)
        presenter.proceed()

        // then

        wait(for: [inputViewModelReloaded, completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingUnbondSetupViewProtocol,
        wireframe: MockStakingUnbondSetupWireframeProtocol
    ) throws -> StakingUnbondSetupPresenterProtocol {
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

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

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
            total: BigUInt(1e+12),
            active: BigUInt(1e+12),
            unlocking: [],
            claimedRewards: []
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: stakingLedger,
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+12)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: nil)
        )

        let interactor = StakingUnbondSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDurationOperationFactory: StakingDurationOperationFactory(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager
        )

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            assetInfo: chainAsset.assetDisplayInfo
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let inputExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let bondingDurationExpectation = XCTestExpectation()

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

            when(stub).didReceiveBonding(duration: any()).then { viewModel in
                if !viewModel.value(for: Locale.current).isEmpty {
                    bondingDurationExpectation.fulfill()
                }
            }

            when(stub).didReceiveInput(viewModel: any()).then { _ in
                inputExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [inputExpectation, assetExpectation, feeExpectation, bondingDurationExpectation], timeout: 10)

        return presenter
    }
}
