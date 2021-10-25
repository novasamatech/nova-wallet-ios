import XCTest
@testable import fearless
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import RobinHood
import Cuckoo
import BigInt

class StakingPayoutsConfirmTests: XCTestCase {
    func testSetupAndSendExtrinsic() throws {
        // given

        let address = "5E9W1jho79KwmnwxnGjGaBEyWw9XFjhu3upEaDtwWSvVgbou"
        let validatorAccountId = try address.toAccountId()

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let metaAccount = AccountGenerator.generateMetaAccount()
        let selectedAccount = metaAccount.fetch(for: chain.accountRequest())!

        let view = MockStakingPayoutConfirmationViewProtocol()
        let wireframe = MockStakingPayoutConfirmationWireframeProtocol()

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let viewModelFactory = StakingPayoutConfirmViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory,
            payoutConfirmViewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            logger: nil
        )

        let extrinsicService = ExtrinsicServiceStub.dummy()
        let signer = try DummySigner(cryptoType: MultiassetCryptoType.sr25519)

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub()
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(2e+12)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: nil)
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())

        let extrinsicOperationFactory = ExtrinsicOperationFactoryStub()

        let interactor = StakingPayoutConfirmationInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicOperationFactory: extrinsicOperationFactory,
            extrinsicService: extrinsicService,
            runtimeService: chainRegistry.getRuntimeProvider(for: chain.chainId)!,
            signer: signer,
            accountRepositoryFactory: accountRepositoryFactory,
            operationManager: OperationManager(),
            payouts: [PayoutInfo(era: 1000, validator: validatorAccountId, reward: 1, identity: nil)]
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let viewModelExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(feeViewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didRecieve(viewModel: any()).then {_ in
                viewModelExpectation.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()

            when(stub).localizationManager.get.then { LocalizationManager.shared }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }

            when(stub).present(
                message: any(),
                title: any(),
                closeAction: any(),
                from: any()).thenDoNothing()
        }

        // when

        presenter.setup()

        // then

        wait(for: [feeExpectation, viewModelExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
