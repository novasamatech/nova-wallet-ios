import XCTest
@testable import fearless
import Cuckoo
import SoraKeystore
import IrohaCrypto
import SubstrateSdk
import SoraFoundation

class ValidatorInfoTests: XCTestCase {
    let validator = SelectedValidatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6")

    func testSetup() {
        // given

        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: selectedChain, asset: selectedChain.assets.first!)

        let view = MockValidatorInfoViewProtocol()
        let wireframe = MockValidatorInfoWireframeProtocol()

        let priceProvider = PriceProviderFactoryStub(priceData: PriceData(price: "0.1", usdDayChange: 0.1))

        let interactor = AnyValidatorInfoInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProvider,
            validatorInfo: validator
        )

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didRecieve(state: any()).then { _ in
                expectation.fulfill()
            }
        }

        interactor.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }

    func testYourValidatorSetup() {
        // given
        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let view = MockValidatorInfoViewProtocol()
        let wireframe = MockValidatorInfoWireframeProtocol()

        let chainAsset = ChainAsset(chain: selectedChain, asset: selectedChain.assets.first!)

        let validatorOperationFactory = ValidatorOperationFactoryStub(
            electedValidatorList: WestendStub.allValidators
        )

        let priceProvider = PriceProviderFactoryStub(priceData: PriceData(price: "0.1", usdDayChange: 0.1))

        let interactor = YourValidatorInfoInteractor(
            accountAddress: validator.address,
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProvider,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didRecieve(state: any()).then { state in
                switch state {
                case .validatorInfo:
                    expectation.fulfill()
                case .error:
                    XCTFail("Unexpected error")
                case .loading, .empty:
                    break
                }
            }
        }

        interactor.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
