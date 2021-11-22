import XCTest
@testable import novawallet
import Cuckoo
import RobinHood
import SubstrateSdk
import SoraKeystore
import SoraFoundation
import BigInt

class StakingUnbondConfirmTests: XCTestCase {

    func testUnbondingConfirmationSuccess() throws {
        // given

        let view = MockStakingUnbondConfirmViewProtocol()
        let wireframe = MockStakingUnbondConfirmWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: 1.0, view: view, wireframe: wireframe)

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()

            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()

            when(stub).didReceiveConfirmation(viewModel: any()).thenDoNothing()

            when(stub).localizationManager.get.then { nil }

            when(stub).didStartLoading().thenDoNothing()

            when(stub).didStopLoading().thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.confirm()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for inputAmount: Decimal,
        view: MockStakingUnbondConfirmViewProtocol,
        wireframe: MockStakingUnbondConfirmWireframeProtocol
    ) throws -> StakingUnbondConfirmPresenterProtocol {
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
            payee: RewardDestinationArg.staked,
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+12)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: nil)
        )

        let interactor = StakingUnbondConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let confirmViewModelFactory = StakingUnbondConfirmViewModelFactory(assetInfo: assetInfo)

        let presenter = StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: inputAmount,
            confirmViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            assetInfo: assetInfo,
            explorers: nil
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let confirmViewModelExpectation = XCTestExpectation()

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

            when(stub).didReceiveConfirmation(viewModel: any()).then { viewModel in
                confirmViewModelExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [assetExpectation, feeExpectation, confirmViewModelExpectation], timeout: 10)

        return presenter
    }
}
