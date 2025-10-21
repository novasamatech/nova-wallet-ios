import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import BigInt

class StakingRebondSetupTests: XCTestCase {
    func testRebondSetupAndAmountProvidingSuccess() throws {
        // given

        let view = MockStakingRebondSetupViewProtocol()
        let wireframe = MockStakingRebondSetupWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: view, wireframe: wireframe)

        stub(view) { stub in
            when(stub.didReceiveAsset(viewModel: any())).thenDoNothing()
            when(stub.didReceiveFee(viewModel: any())).thenDoNothing()
            when(stub.didReceiveTransferable(viewModel: any())).thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.proceed(view: any(), amount: any())).then { _, _ in
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

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub()

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress, chainId: chain.chainId)
        let stakingLedger = Staking.Ledger(
            stash: selectedAccount.accountId,
            total: BigUInt(3e+12),
            active: BigUInt(1e+12),
            unlocking: [
                Staking.UnlockChunk(value: BigUInt(2e+12), era: 5)
            ],
            claimedRewards: [],
            legacyClaimedRewards: nil
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(
            ledgerInfo: stakingLedger,
            activeEra: Staking.ActiveEraInfo(index: 1),
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

        let interactor = StakingRebondSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            feeProxy: ExtrinsicFeeProxy(),
            currencyManager: CurrencyManagerStub(),
            operationQueue: operationQueue
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let inputExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
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

            when(stub.didReceiveInput(viewModel: any())).then { _ in
                inputExpectation.fulfill()
            }

            when(stub.didReceiveTransferable(viewModel: any())).then { optViewModel in
                if optViewModel != nil {
                    transferableExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        // then

        wait(for: [inputExpectation, assetExpectation, feeExpectation, transferableExpectation], timeout: 10)

        return presenter
    }
}
