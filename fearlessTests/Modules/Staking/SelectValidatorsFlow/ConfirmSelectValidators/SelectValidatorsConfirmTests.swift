import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import BigInt
import Cuckoo
import SoraFoundation

class SelectValidatorsConfirmTests: XCTestCase {
    let initiatedBoding: PreparedNomination<InitiatedBonding> = {
        let validator1 = SelectedValidatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6",
                                               identity: nil)
        let validator2 = SelectedValidatorInfo(address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq",
                                               identity: nil)
        let initiatedBonding = InitiatedBonding(amount: 1.0, rewardDestination: .restake)

        return PreparedNomination(bonding: initiatedBonding,
                                  targets: [validator1, validator2],
                                  maxTargets: 16)
    }()

    func testSetupAndSendExtrinsic() throws {
        // given

        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: chain, asset: chain.assets.first!)

        let view = MockSelectValidatorsConfirmViewProtocol()
        let wireframe = MockSelectValidatorsConfirmWireframeProtocol()

        let confirmViewModelFactory = SelectValidatorsConfirmViewModelFactory()
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let signer = try DummySigner(cryptoType: MultiassetCryptoType.sr25519)

        let extrinsicService = ExtrinsicServiceStub.dummy()

        let selectedMetaAccount  = AccountGenerator.generateMetaAccount()
        let selectedAccount = selectedMetaAccount.fetch(for: chain.accountRequest())!

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])
        let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId)!

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactoryStub()
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactoryStub(balance: BigUInt(1e+14))
        let priceLocalSubscriptionFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: 0.1)
        )

        let interactor = InitiatedBondingConfirmInteractor(
            selectedAccount: try selectedAccount.toDisplayAddress(),
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: OperationManager(),
            signer: signer,
            nomination: initiatedBoding
        )

        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: chainAsset.assetDisplayInfo
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        // when

        let feeExpectation = XCTestExpectation()
        let assetExpectation = XCTestExpectation()
        let confirmExpectation = XCTestExpectation()
        let hintExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(feeViewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didReceive(assetViewModel: any()).then { _ in
                assetExpectation.fulfill()
            }

            when(stub).didReceive(confirmationViewModel: any()).then { _ in
                confirmExpectation.fulfill()
            }

            when(stub).didReceive(hintsViewModel: any()).then { _ in
                hintExpectation.fulfill()
            }

            when(stub).localizationManager.get.thenReturn(LocalizationManager.shared)

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [feeExpectation, assetExpectation, confirmExpectation, hintExpectation],
             timeout: Constants.defaultExpectationDuration)

        // when

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
