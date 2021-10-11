import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils
import SoraFoundation
import SoraKeystore

class ValidatorListFilterTests: XCTestCase {
    func testSetupAndChangeFilter() {
        // given
        let view = MockValidatorListFilterViewProtocol()
        let wireframe = MockValidatorListFilterWireframeProtocol()
        let viewModelFactory = ValidatorListFilterViewModelFactory()

        let assetInfo = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42
        ).assets.first!.displayInfo

        let presenter = ValidatorListFilterPresenter(wireframe: wireframe,
                                                     viewModelFactory: viewModelFactory,
                                                     assetInfo: assetInfo,
                                                     filter: CustomValidatorListFilter.recommendedFilter(),
                                                     localizationManager: LocalizationManager.shared)

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()
        let filterChangeExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didUpdateViewModel(any()).then { viewModel in
                XCTAssertFalse(viewModel.canApply)
                XCTAssertFalse(viewModel.canReset)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        stub(view) { stub in
            when(stub).didUpdateViewModel(any()).then { viewModel in
                XCTAssertTrue(viewModel.canApply)
                XCTAssertTrue(viewModel.canReset)
                filterChangeExpectation.fulfill()
            }
        }

        presenter.toggleFilterItem(at: 1)

        // then

        wait(
            for: [reloadExpectation, filterChangeExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }}
