import XCTest
@testable import novawallet
import Cuckoo
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS

class CustomValidatorListTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            assetPresicion: 12,
            hasStaking: true
        )

        let chainAsset = ChainAsset(chain: selectedChain, asset: selectedChain.assets.first!)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )

        let viewModelFactory = CustomValidatorListViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "0.1",
                dayChange: 0.1,
                currencyId: Currency.usd.id
            )
        )

        let interactor = CustomValidatorListInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProviderFactory,
            currencyManager: CurrencyManagerStub()
        )

        let generator = CustomValidatorListTestDataGenerator.self

        let fullValidatorList = generator
            .createSelectedValidators(from: WestendStub.recommendedValidators)

        let recommendedValidatorList = generator
            .createSelectedValidators(from: WestendStub.recommendedValidators)

        let validatorsSelectionParams = ValidatorsSelectionParams(maxNominations: 16, hasIdentity: true)

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            fullValidatorList: .init(allValidators: fullValidatorList, preferredValidators: []),
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: SharedList<SelectedValidatorInfo>(items: []),
            validatorsSelectionParams: validatorsSelectionParams
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let reloadExpectation = XCTestExpectation()
        let filterExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).setFilterAppliedState(to: any()).then { _ in
                filterExpectation.fulfill()
            }

            when(stub).reload(any(), at: any()).then { (viewModel, _) in
                XCTAssertEqual(WestendStub.recommendedValidators.count, viewModel.cellViewModels.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [reloadExpectation, filterExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
