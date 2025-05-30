import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import BigInt

class StakingRebondConfirmationTests: XCTestCase {

    func testRebondConfirmationSuccess() throws {
        // given

        let view = MockStakingRebondConfirmationViewProtocol()
        let wireframe = MockStakingRebondConfirmationWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: 0.1, view: view, wireframe: wireframe)

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceiveAmount(viewModel: any()).thenDoNothing()

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
        view: MockStakingRebondConfirmationViewProtocol,
        wireframe: MockStakingRebondConfirmationWireframeProtocol
    ) throws -> StakingRebondConfirmationPresenterProtocol {
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
            extrinsicService: ExtrinsicServiceStub.dummy()
        )

        let stashItem = StashItem(stash: nominatorAddress, controller: nominatorAddress, chainId: chain.chainId)
        let stakingLedger = StakingLedger(
            stash: selectedAccount.accountId,
            total: BigUInt(3e+12),
            active: BigUInt(1e+12),
            unlocking: [
                UnlockChunk(value: BigUInt(2e+12), era: 5)
            ],
            claimedRewards: [],
            legacyClaimedRewards: nil
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
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: nil,
                currencyId: Currency.usd.id
            )
        )

        let interactor = StakingRebondConfirmationInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: DummySigningWrapperFactory(),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager,
            currencyManager: CurrencyManagerStub()
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let confirmViewModelFactory = StakingRebondConfirmationViewModelFactory()

        let presenter = StakingRebondConfirmationPresenter(
            variant: .custom(amount: inputAmount),
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            assetInfo: assetInfo,
            chain: chainAsset.chain
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let confirmViewModelExpectation = XCTestExpectation()

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
        }

        presenter.setup()

        // then

        wait(for: [assetExpectation, feeExpectation, confirmViewModelExpectation], timeout: 10)

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
