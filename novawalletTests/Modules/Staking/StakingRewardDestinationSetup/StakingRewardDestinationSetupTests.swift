import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import BigInt

class StakingRewardDestinationSetupTests: XCTestCase {
    struct PresenterSetupResult {
        let presenter: StakingRewardDestSetupPresenter
        let outputProxy: StakingRewardDestSetupInteractorOutputProtocol
    }
    
    func testRewardDestinationSetupSuccess() throws {
        // given

        let view = MockStakingRewardDestSetupViewProtocol()
        let wireframe = MockStakingRewardDestSetupWireframeProtocol()

        let newPayoutAccount = AccountGenerator.generateMetaAccount()

        // when

        let presenterResult = try setupPresenter(for: view, wireframe: wireframe, newPayout: newPayoutAccount)

        let changesApplied = XCTestExpectation()

        // after changes from restake to payout and after account selection
        changesApplied.expectedFulfillmentCount = 2

        stub(view) { stub in
            when(stub.didReceiveRewardDestination(viewModel: any())).then { viewModel in
                if let viewModel = viewModel, viewModel.canApply {
                    changesApplied.fulfill()
                }
            }

            when(stub.didReceiveFee(viewModel: any())).thenDoNothing()
            when(stub.didCompletionAccountSelection()).thenDoNothing()
        }

        let payoutSelectionsExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.presentAccountSelection(
                any(),
                selectedAccountItem: any(),
                title: any(),
                delegate: any(),
                from: any(),
                context: any()
            )).then { (accounts, _, _, delegate, _, context) in
                if let index = accounts.firstIndex(
                    where: { newPayoutAccount.substrateAccountId == $0.substrateAccountId }) {
                    delegate.modalPickerDidSelectModelAtIndex(index, context: context)

                    payoutSelectionsExpectation.fulfill()
                } else {
                    delegate.modalPickerDidCancel(context: context)
                }
            }

            when(stub.proceed(view: any(), rewardDestination: any())).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenterResult.presenter.selectPayoutDestination()
        presenterResult.presenter.selectPayoutAccount()

        wait(for: [changesApplied, payoutSelectionsExpectation], timeout: 10.0)

        presenterResult.presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for view: MockStakingRewardDestSetupViewProtocol,
        wireframe: MockStakingRewardDestSetupWireframeProtocol,
        newPayout: MetaAccountModel?
    ) throws -> PresenterSetupResult {
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
        let stashItem = StashItem(stash: address, controller: address, chainId: chain.chainId)
        let ledgerInfo = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(2e+12),
            active: BigUInt(2e+12),
            unlocking: [],
            claimedRewards: [],
            legacyClaimedRewards: nil
        )

        let payee = Staking.RewardDestinationArg.staked

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: ledgerInfo,
            payee: payee,
            stashItem: stashItem
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(balance: BigUInt(1e+14))

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: 0.1,
                currencyId: Currency.usd.id
            )
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy()
        )

        let interactor = StakingRewardDestSetupInteractor(
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
            feeProxy: ExtrinsicFeeProxy(),
            currencyManager: CurrencyManagerStub()
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let viewModelFactory = ChangeRewardDestinationViewModelFactory(
            rewardDestinationViewModelFactory: rewardDestViewModelFactory
        )

        let validationFactory = StakingDataValidatingFactory(presentable: wireframe)
        
        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: viewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: validationFactory,
            applicationConfig: ApplicationConfig.shared,
            assetInfo: assetInfo,
            localizationManager: LocalizationManager.shared
        )

        let mockedPresenter = MockStakingRewardDestSetupInteractorOutputProtocol()
        
        presenter.view = view
        interactor.presenter = mockedPresenter
        validationFactory.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let rewardDestinationExpectation = XCTestExpectation()
        let balanceExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceiveFee(viewModel: any())).then { feeViewModel in
                if feeViewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub.didReceiveRewardDestination(viewModel: any())).then { viewModel in
                if let viewModel = viewModel, !viewModel.canApply {
                    rewardDestinationExpectation.fulfill()
                }
            }
        }
        
        stub(mockedPresenter) { stub in
            when(stub.didReceiveFee(result: any())).then { fee in
                presenter.didReceiveFee(result: fee)
            }
            
            when(stub.didReceivePriceData(result: any())).then { result in
                presenter.didReceivePriceData(result: result)
            }
            
            when(stub.didReceiveStashItem(result: any())).then { result in
                presenter.didReceiveStashItem(result: result)
            }

            when(stub.didReceiveStakingLedger(result: any())).then { result in
                presenter.didReceiveStakingLedger(result: result)
            }
            
            when(stub.didReceiveController(result: any())).then { result in
                presenter.didReceiveController(result: result)
            }
            
            when(stub.didReceiveStash(result: any())).then { result in
                presenter.didReceiveStash(result: result)
            }
            
            when(stub.didReceiveRewardDestinationAccount(result: any())).then { result in
                presenter.didReceiveRewardDestinationAccount(result: result)
            }
            
            when(stub.didReceiveRewardDestinationAddress(result: any())).then { result in
                presenter.didReceiveRewardDestinationAddress(result: result)
            }

            when(stub.didReceiveCalculator(result: any())).then { result in
                presenter.didReceiveCalculator(result: result)
            }
            
            when(stub.didReceiveAccounts(result: any())).then { result in
                presenter.didReceiveAccounts(result: result)
            }
            
            when(stub.didReceiveNomination(result: any())).then { result in
                presenter.didReceiveNomination(result: result)
            }
            
            when(stub.didReceiveAccountBalance(result: any())).then { result in
                presenter.didReceiveAccountBalance(result: result)
                
                if case .success = result {
                    balanceExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        // then

        wait(for: [feeExpectation, rewardDestinationExpectation, balanceExpectation], timeout: 20)

        return PresenterSetupResult(presenter: presenter, outputProxy: mockedPresenter)
    }

}
