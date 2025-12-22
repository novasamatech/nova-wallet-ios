import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
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
            when(stub.didReceiveInput(viewModel: any())).then { _ in
                inputViewModelReloaded.fulfill()
            }

            when(stub.didReceiveAsset(viewModel: any())).thenDoNothing()
            when(stub.didReceiveFee(viewModel: any())).thenDoNothing()
            when(stub.didReceiveBonding(duration: any())).thenDoNothing()
            when(stub.didReceiveTransferable(viewModel: any())).thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.proceed(view: any(), amount: any())).then { _, _ in
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

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub()

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress, chainId: chain.chainId)
        let stakingLedger = Staking.Ledger(
            stash: selectedAccount.accountId,
            total: BigUInt(1e+12),
            active: BigUInt(1e+12),
            unlocking: [],
            claimedRewards: [],
            legacyClaimedRewards: nil
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: stakingLedger,
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

        let interactor = StakingUnbondSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDurationOperationFactory: BabeStakingDurationFactory(
                chainId: chain.chainId,
                chainRegistry: chainRegistry
            ),
            extrinsicServiceFactory: extrinsicServiceFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationQueue: operationQueue,
            currencyManager: CurrencyManagerStub()
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let inputExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let bondingDurationExpectation = XCTestExpectation()
        let transferableExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceiveAsset(viewModel: any())).then { viewModel in
                if let balance = viewModel.value(for: Locale.current).balance, !balance.isEmpty {
                    assetExpectation.fulfill()
                }
            }

            when(stub.didReceiveFee(viewModel: any())).then { viewModel in
                if let fee = viewModel?.value(for: Locale.current).amount, !fee.isEmpty {
                    feeExpectation.fulfill()
                }
            }

            when(stub.didReceiveBonding(duration: any())).then { viewModel in
                if !viewModel.value(for: Locale.current).isEmpty {
                    bondingDurationExpectation.fulfill()
                }
            }

            when(stub.didReceiveInput(viewModel: any())).then { _ in
                inputExpectation.fulfill()
            }

            when(stub.didReceiveTransferable(viewModel: any())).then { _ in
                transferableExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [
            inputExpectation,
            assetExpectation,
            feeExpectation,
            bondingDurationExpectation,
            transferableExpectation
        ], timeout: 10)

        return presenter
    }
}
