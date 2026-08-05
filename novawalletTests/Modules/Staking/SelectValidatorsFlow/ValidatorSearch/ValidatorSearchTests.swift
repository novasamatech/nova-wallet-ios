import XCTest
@testable import novawallet
import Cuckoo
import SubstrateSdk
import Foundation_iOS

class ValidatorSearchTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockValidatorSearchViewProtocol()
        let wireframe = MockValidatorSearchWireframeProtocol()
        let viewModelFactory = ValidatorSearchViewModelFactory(lockedAddresses: [])
        let validatorOperationFactory = ValidatorOperationFactoryProtocolStub()

        let interactor = ValidatorSearchInteractor(
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )

        let generator = CustomValidatorListTestDataGenerator.self

        let selectedValidatorList = generator
            .createSelectedValidators(from: [generator.goodValidator])

        let fullValidatorList = generator
            .createSelectedValidators(from: generator.goodValidators)

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            fullValidatorList: fullValidatorList,
            selectedValidatorList: selectedValidatorList,
            lockedAddresses: [],
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReset()).thenDoNothing()

            when(stub.didReload(any())).then { viewModel in
                XCTAssertEqual(viewModel.cellViewModels.count, fullValidatorList.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()
        presenter.search(for: "val")

        // then

        wait(
            for: [reloadExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }

    func testLockedValidatorCannotBeToggledInSearch() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])
        let fullList = generator.createSelectedValidators(from: generator.goodValidators) + locked

        let view = MockValidatorSearchViewProtocol()
        let wireframe = MockValidatorSearchWireframeProtocol()
        let interactor = MockValidatorSearchInteractorInputProtocol()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: ValidatorSearchViewModelFactory(
                lockedAddresses: Set(locked.map(\.address))
            ),
            fullValidatorList: fullList,
            selectedValidatorList: locked,
            lockedAddresses: Set(locked.map(\.address)),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        var lastViewModel: ValidatorSearchViewModel?

        stub(view) { stub in
            when(stub.didReload(any())).then { viewModel in
                lastViewModel = viewModel
            }
            when(stub.didReset()).thenDoNothing()
            when(stub.didStartSearch()).thenDoNothing()
            when(stub.didStopSearch()).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub.present(message: any(), title: any(), closeAction: any(), from: any()))
                .thenDoNothing()
        }

        // when

        presenter.search(for: locked[0].address)
        presenter.changeValidatorSelection(at: 0)

        // then

        XCTAssertEqual(lastViewModel?.cellViewModels.first?.isLocked, true)
        XCTAssertEqual(lastViewModel?.cellViewModels.first?.isSelected, true)
    }
}
