import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import BigInt

class BondMoreConfirmTests: XCTestCase {

    func testBondMoreConfirmationSuccess() throws {
        // given

        let view = MockStakingBondMoreConfirmationViewProtocol()
        let wireframe = MockStakingBondMoreConfirmationWireframeProtocol()

        // when

        let presenter = try setupPresenter(for: 0.1, view: view, wireframe: wireframe)

        let completionExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceiveAmount(viewModel: any())).thenDoNothing()

            when(stub.didReceiveFee(viewModel: any())).thenDoNothing()

            when(stub.didReceiveConfirmation(viewModel: any())).thenDoNothing()

            when(stub.didStartLoading()).thenDoNothing()

            when(stub.didStopLoading()).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub.presentExtrinsicSubmission(
                from: any(),
                params: any()
            )).then { _ in
                completionExpectation.fulfill()
            }
        }

        presenter.confirm()

        // then

        wait(for: [completionExpectation], timeout: 10.0)
    }

    private func setupPresenter(
        for inputAmount: Decimal,
        view: MockStakingBondMoreConfirmationViewProtocol,
        wireframe: MockStakingBondMoreConfirmationWireframeProtocol
    ) throws -> StakingBondMoreConfirmationPresenterProtocol {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let metaAccount = AccountGenerator.generateMetaAccount()
        let accountResponse = metaAccount.fetch(for: chain.accountRequest())!
        let selectedAddress = accountResponse.toAddress()!
        let stashItem = StashItem(stash: selectedAddress, controller: selectedAddress, chainId: chain.chainId)

        let userDataStorage = UserDataStorageTestFacade()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: userDataStorage)
        let accountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        // save controller
        let operationQueue = OperationQueue()
        let managedMetaAccount = ManagedMetaAccountModel(info: metaAccount)

        let saveControllerOperation = accountRepository.saveOperation({ [managedMetaAccount] }, { [] })
        operationQueue.addOperations([saveControllerOperation], waitUntilFinished: true)

        let extrinsicServiceFactory = ExtrinsicServiceFactoryStub(
            extrinsicService: ExtrinsicServiceStub.dummy()
        )

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub(stashItem: stashItem)
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(balance: BigUInt(1e+12))
        let priceSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.01",
                dayChange: nil,
                currencyId: Currency.usd.id
            )
        )
        
        let runtimeProvider = MockRuntimeProviderProtocol().applyDefault(for: KnowChainId.westend)

        let interactor = StakingBondMoreConfirmationInteractor(
            selectedAccount: accountResponse,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: DummySigningWrapperFactory(),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceSubscriptionFactory,
            feeProxy: ExtrinsicFeeProxy(),
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            currencyManager: CurrencyManagerStub()
        )

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let confirmViewModelFactory = StakingBondMoreConfirmViewModelFactory()

        let presenter = StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: inputAmount,
            confirmViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            assetInfo: assetInfo,
            chain: chainAsset.chain,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let confirmViewModelExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceiveAmount(viewModel: any())).then { viewModel in
                let balance = viewModel.value(for: Locale.current).amount

                if !balance.isEmpty {
                    assetExpectation.fulfill()
                }
            }

            when(stub.didReceiveFee(viewModel: any())).then { viewModel in
                if let fee = viewModel?.value(for: Locale.current).amount, !fee.isEmpty {
                    feeExpectation.fulfill()
                }
            }

            when(stub.didReceiveConfirmation(viewModel: any())).then { viewModel in
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
                    for: accountResponse.accountId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )
            )
        )

        return presenter
    }

}
