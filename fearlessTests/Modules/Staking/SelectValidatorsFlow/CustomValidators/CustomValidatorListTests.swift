import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils
import SoraKeystore
import SoraFoundation

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

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        let viewModelFactory = CustomValidatorListViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "0.1", usdDayChange: 0.1)
        )

        let interactor = CustomValidatorListInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: priceProviderFactory
        )

        let generator = CustomValidatorListTestDataGenerator.self

        let fullValidatorList = generator
            .createSelectedValidators(from: WestendStub.recommendedValidators)

        let recommendedValidatorList = generator
            .createSelectedValidators(from: WestendStub.recommendedValidators)

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            fullValidatorList: fullValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: SharedList<SelectedValidatorInfo>(items: []),
            maxTargets: 16
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
