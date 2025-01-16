import XCTest
@testable import novawallet
import Cuckoo
import SubstrateSdk
import Foundation_iOS
import Keystore_iOS

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

        let hasIdentity = true
        let filter = CustomValidatorListFilter.recommendedFilter(havingIdentity: hasIdentity)
        let presenter = ValidatorListFilterPresenter(wireframe: wireframe,
                                                     viewModelFactory: viewModelFactory,
                                                     assetInfo: assetInfo,
                                                     filter: filter,
                                                     hasIdentity: hasIdentity,
                                                     localizationManager: LocalizationManager.shared)

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()
        let filterChangeExpectation = XCTestExpectation()

        var optFilterViewModel: ValidatorListFilterViewModel?

        stub(view) { stub in
            when(stub).didUpdateViewModel(any()).then { viewModel in
                optFilterViewModel = viewModel

                XCTAssertFalse(viewModel.canApply)
                XCTAssertFalse(viewModel.canReset)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        wait(for: [reloadExpectation], timeout: Constants.defaultExpectationDuration)

        guard let filterViewModel = optFilterViewModel else {
            XCTFail("Expectedn not null view model")
            return
        }

        stub(view) { stub in
            when(stub).didUpdateViewModel(any()).then { viewModel in
                XCTAssertTrue(viewModel.canApply)
                XCTAssertTrue(viewModel.canReset)
                filterChangeExpectation.fulfill()
            }
        }

        presenter.toggleFilter(for: filterViewModel.filterModel.cellViewModels[1])

        // then

        wait(for: [filterChangeExpectation], timeout: Constants.defaultExpectationDuration)
    }}
