import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import NovaCrypto
import SubstrateSdk
import Foundation_iOS

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

        let priceProvider = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: 0.1,
                currencyId: Currency.usd.id
            )
        )

        let interactor = AnyValidatorInfoInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProvider,
            validatorInfo: validator,
            currencyManager: CurrencyManagerStub()
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            localizationManager: LocalizationManager.shared,
            chain: chainAsset.chain
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didRecieve(state: any())).then { _ in
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

        let priceProvider = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: 0.1,
                currencyId: Currency.usd.id
            )
        )

        let interactor = YourValidatorInfoInteractor(
            accountAddress: validator.address,
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProvider,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager,
            currencyManager: CurrencyManagerStub()
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            localizationManager: LocalizationManager.shared,
            chain: chainAsset.chain
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didRecieve(state: any())).then { state in
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
