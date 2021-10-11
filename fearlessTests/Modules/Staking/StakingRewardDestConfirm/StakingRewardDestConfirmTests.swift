import XCTest
@testable import fearless
import Cuckoo
import RobinHood
import FearlessUtils
import SoraKeystore
import SoraFoundation
import BigInt

class StakingRewardDestConfirmTests: XCTestCase {

    func testRewardDestinationConfirmSuccess() throws {
        // given

        let view = MockStakingRewardDestConfirmViewProtocol()
        let wireframe = MockStakingRewardDestConfirmWireframeProtocol()

        let newPayoutAccount = AccountGenerator.generateMetaAccount()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe, newPayout: newPayoutAccount)

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in

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
        for view: MockStakingRewardDestConfirmViewProtocol,
        wireframe: MockStakingRewardDestConfirmWireframeProtocol,
        newPayout: MetaAccountModel?
    ) throws -> StakingRewardDestConfirmPresenter {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)
        let metaAccount = AccountGenerator.generateMetaAccount()
        let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest())!

        let operationManager = OperationManager()

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageTestFacade()
        )

        let accountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // save controller and payout
        let saveControllerOperation = accountRepository
            .saveOperation({
                if let payout = newPayout {
                    return [
                        ManagedMetaAccountModel(info: metaAccount, isSelected: true, order: 0),
                        ManagedMetaAccountModel(info: payout, isSelected: false, order: 1)
                    ]
                } else {
                    return [
                        ManagedMetaAccountModel(info: metaAccount, isSelected: true, order: 0)
                    ]
                }
            }, { [] })
        OperationQueue().addOperations([saveControllerOperation], waitUntilFinished: true)

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])
        let calculatorService = RewardCalculatorServiceStub(engine: WestendStub.rewardCalculator)

        let address = selectedAccount.toAddress()!
        let stashItem = StashItem(stash: address, controller: address)

        let ledgerInfo = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(2e+12),
            active: BigUInt(2e+12),
            unlocking: [],
            claimedRewards: []
        )

        let payee = RewardDestinationArg.staked

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: ledgerInfo,
            payee: payee,
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(balance: BigUInt(1e+14))

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: 0.1)
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy(),
            signingWraper: try DummySigner(cryptoType: MultiassetCryptoType.sr25519)
        )

        let interactor = StakingRewardDestConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            calculatorService: calculatorService,
            runtimeService: chainRegistry.getRuntimeProvider(for: chain.chainId)!,
            operationManager: operationManager,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy()
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let newPayoutItem = try newPayout?.fetch(for: chain.accountRequest())?.toAccountItem()
        let rewardDestination = newPayoutItem.map { RewardDestination.payout(account: $0) } ?? .restake

        let dataValidating = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: rewardDestination,
            confirmModelFactory: StakingRewardDestConfirmVMFactory(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidating,
            assetInfo: assetInfo
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidating.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let rewardDestinationExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveFee(viewModel: any()).then { feeViewModel in
                if feeViewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceiveConfirmation(viewModel: any()).then { _ in
                rewardDestinationExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, rewardDestinationExpectation], timeout: 10)

        return presenter
    }

}
