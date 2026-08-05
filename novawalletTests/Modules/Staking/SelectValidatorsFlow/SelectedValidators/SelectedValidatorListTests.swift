import XCTest
@testable import novawallet
import Cuckoo
import SubstrateSdk
import Foundation_iOS

class SelectedValidatorListTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockSelectedValidatorListViewProtocol()
        let wireframe = MockSelectedValidatorListWireframeProtocol()
        let viewModelFactory = SelectedValidatorListViewModelFactory(lockedAddresses: [])

        let generator = CustomValidatorListTestDataGenerator.self

        let selectedvalidatorList = generator.createSelectedValidators(
            from: generator.goodValidators
        )

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidatorList: selectedvalidatorList,
            maxTargets: 16,
            lockedAddresses: []
        )

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()
        let removeLastExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReload(any())).then { viewModel in
                XCTAssertEqual(viewModel.cellViewModels.count, selectedvalidatorList.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        stub(view) { stub in
            when(
                stub.didChangeViewModel(
                    any(),
                    byRemovingItemAt: any()
                )
            ).then { viewModel, index in
                XCTAssertEqual(index, viewModel.cellViewModels.count)
                removeLastExpectation.fulfill()
            }
        }

        presenter.removeItem(at: selectedvalidatorList.count - 1)

        // then

        wait(
            for: [reloadExpectation, removeLastExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }

    func testLockedValidatorCannotBeRemoved() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])
        let community = generator.createSelectedValidators(from: generator.goodValidators)

        let view = MockSelectedValidatorListViewProtocol()
        let wireframe = MockSelectedValidatorListWireframeProtocol()
        let delegate = MockSelectedValidatorListDelegate()

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: SelectedValidatorListViewModelFactory(
                lockedAddresses: Set(locked.map(\.address))
            ),
            localizationManager: LocalizationManager.shared,
            selectedValidatorList: community + locked,
            maxTargets: 16,
            lockedAddresses: Set(locked.map(\.address))
        )

        presenter.view = view
        presenter.delegate = delegate

        var lastViewModel: SelectedValidatorListViewModel?

        stub(view) { stub in
            when(stub.didReload(any())).then { viewModel in
                lastViewModel = viewModel
            }
            when(stub.didChangeViewModel(any(), byRemovingItemAt: any())).thenDoNothing()
        }

        stub(delegate) { stub in
            when(stub.didRemove(any())).thenDoNothing()
        }

        presenter.setup()

        // when: the locked validator is the last row

        let lockedIndex = community.count
        presenter.removeItem(at: lockedIndex)

        // then

        XCTAssertEqual(lastViewModel?.cellViewModels[lockedIndex].isLocked, true)
        XCTAssertEqual(lastViewModel?.cellViewModels.count, community.count + locked.count)
        verify(delegate, never()).didRemove(any())
    }
}
