import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
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
            when(stub).didReceiveAmount(viewModel: any()).thenDoNothing()

            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()

            when(stub).didReceiveConfirmation(viewModel: any()).thenDoNothing()

            when(stub).didSetShouldResetRewardsDestination(value: any()).thenDoNothing()

            when(stub).didReceiveBonding(duration: any()).thenDoNothing()

            when(stub).localizationManager.get.then { nil }

            when(stub).didStartLoading().thenDoNothing()

            when(stub).didStopLoading().thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub).presentExtrinsicSubmission(
                from: any(),
                params: any()
            ).then { _ in
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
            extrinsicService: ExtrinsicServiceStub.dummy()
        )

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress, chainId: chain.chainId)
        let stakingLedger = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(1e+12),
            active: BigUInt(1e+12),
            unlocking: [],
            claimedRewards: [],
            legacyClaimedRewards: nil
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: stakingLedger,
            payee: Staking.RewardDestinationArg.staked,
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+12)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: nil,
                currencyId: Currency.usd.id
            )
        )

        let stakingDurationOperationFactory = BabeStakingDurationFactory(
            chainId: chain.chainId,
            chainRegistry: chainRegistry
        )

        let interactor = StakingUnbondConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDurationOperationFactory: stakingDurationOperationFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: DummySigningWrapperFactory(),
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager,
            currencyManager: CurrencyManagerStub()
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let confirmViewModelFactory = StakingUnbondConfirmViewModelFactory()

        let presenter = StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: inputAmount,
            confirmViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            assetInfo: assetInfo,
            chain: ChainModelGenerator.generate(count: 1).first!
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let confirmViewModelExpectation = XCTestExpectation()
        let bondingDurationExpectation = XCTestExpectation()
        let resetsRewardsDestinationExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveAmount(viewModel: any()).then { viewModel in
                let balance = viewModel.value(for: Locale.current).amount
                if !balance.isEmpty {
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

            when(stub).didReceiveBonding(duration: any()).then { _ in
                bondingDurationExpectation.fulfill()
            }

            when(stub).didSetShouldResetRewardsDestination(value: any()).then { _ in
                resetsRewardsDestinationExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [
            assetExpectation,
            feeExpectation,
            confirmViewModelExpectation,
            bondingDurationExpectation,
            resetsRewardsDestinationExpectation
        ], timeout: 10)

        // no way to wait balance receive in presenter
        presenter.didReceiveAccountBalance(
            result: .success(
                walletLocalSubscriptionFactory.getDummyBalance(
                    for: selectedAccount.accountId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )
            )
        )

        return presenter
    }
}
