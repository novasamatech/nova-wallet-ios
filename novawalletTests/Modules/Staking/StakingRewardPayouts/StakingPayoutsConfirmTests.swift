import XCTest
@testable import novawallet
import Foundation_iOS
import Keystore_iOS
import NovaCrypto
import Operation_iOS
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
        let selectedAccount = metaAccount.fetchMetaChainAccount(for: chain.accountRequest())!

        let view = MockStakingPayoutConfirmationViewProtocol()
        let wireframe = MockStakingPayoutConfirmationWireframeProtocol()

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let viewModelFactory = StakingPayoutConfirmViewModelFactory()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory,
            payoutConfirmViewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            chain: chainAsset.chain,
            logger: nil
        )

        let extrinsicService = ExtrinsicServiceStub.dummy()
        let signer = try DummySigner(cryptoType: MultiassetCryptoType.sr25519)

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(2e+12)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: nil,
                currencyId: Currency.usd.id
            )
        )
        
        let runtimeService = try RuntimeCodingServiceStub.createWestendService()

        let interactor = StakingPayoutConfirmationInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            feeProxy: MultiExtrinsicFeeProxy(),
            chainRegistry: chainRegistry,
            signer: signer,
            operationQueue: OperationQueue(),
            payouts: [PayoutInfo(validator: validatorAccountId, era: 1000, pages: [0], reward: 1, identity: nil)],
            currencyManager: CurrencyManagerStub()
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()
        let viewModelExpectation = XCTestExpectation()
        let amounExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(feeViewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didRecieve(viewModel: any()).then {_ in
                viewModelExpectation.fulfill()
            }

            when(stub).didRecieve(amountViewModel: any()).then { _ in
                amounExpectation.fulfill()
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()

            when(stub).localizationManager.get.then { LocalizationManager.shared }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).presentExtrinsicSubmission(
                from: any(),
                params: any()
            ).then { _ in
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

        wait(
            for: [feeExpectation, viewModelExpectation, amounExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        // when

        // no way to wait balance receive in presenter
        presenter.didReceiveAccountBalance(
            result: .success(
                walletLocalSubscriptionFactory.getDummyBalance(
                    for: selectedAccount.chainAccount.accountId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )
            )
        )

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
