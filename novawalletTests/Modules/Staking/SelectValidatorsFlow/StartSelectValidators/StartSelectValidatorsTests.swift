import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS
import Foundation_iOS

class SelectValidatorsStartTests: XCTestCase {
    func testSetupValidators() throws {
        let allValidators = WestendStub.allValidators
        let recomendedValidators = WestendStub.recommendedValidators

        try performTest(
            for: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42),
            selectedTargets: nil,
            allValidators: allValidators,
            expectedRecommendedValidators: recomendedValidators,
            expectedViewModel: SelectValidatorsStartViewModel(
                selectedCount: 0,
                totalCount: 16
            ),
            expectedCustomValidators: allValidators.map { $0.toSelected(for: nil) }
        )
    }

    func testChangeValidators() throws {
        let allValidators = WestendStub.allValidators
        let recomendedValidators = WestendStub.recommendedValidators

        try performTest(
            for: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42),
            selectedTargets: recomendedValidators.map { $0.toSelected(for: nil) },
            allValidators: allValidators,
            expectedRecommendedValidators: recomendedValidators,
            expectedViewModel: SelectValidatorsStartViewModel(
                selectedCount: recomendedValidators.count,
                totalCount: 16
            ),
            expectedCustomValidators: allValidators.map { $0.toSelected(for: nil) }
        )
    }

    func testChangeValidatorsSeedsLockedValidatorsIntoAFullSelection() throws {
        // given

        let allValidators = WestendStub.allValidators
        let generator = CustomValidatorListTestDataGenerator.self

        let initialTargets = (0 ..< 16).map {
            generator.makeSelectedValidator(
                address: "community\($0)",
                stakeReturn: Decimal($0) / 100
            )
        }

        let locked = [
            generator.makeSelectedValidator(address: "nova1", stakeReturn: 0.9),
            generator.makeSelectedValidator(address: "nova2", stakeReturn: 0.8)
        ]

        let module = try makeModule(
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42),
            initialTargets: initialTargets,
            allValidators: allValidators,
            preferredValidators: locked
        )

        let setupExpectation = XCTestExpectation()

        stub(module.view) { stub in
            when(stub.didReceive(viewModel: any())).then { _ in
                setupExpectation.fulfill()
            }
        }

        var capturedSelection: [SelectedValidatorInfo]?

        stub(module.wireframe) { stub in
            when(
                stub.proceedToCustomList(
                    from: any(),
                    selectionValidatorGroups: any(),
                    selectedValidatorList: any(),
                    validatorsSelectionParams: any()
                )
            ).then { _, _, selectedValidatorList, _ in
                capturedSelection = selectedValidatorList.items
            }
        }

        // when

        module.presenter.setup()

        wait(for: [setupExpectation], timeout: 10)

        module.presenter.selectCustomValidators()

        // then

        let selectedAddresses = capturedSelection?.map(\.address) ?? []

        XCTAssertEqual(selectedAddresses.count, 16)
        XCTAssertTrue(selectedAddresses.contains("nova1"))
        XCTAssertTrue(selectedAddresses.contains("nova2"))
        XCTAssertEqual(Set(selectedAddresses).count, selectedAddresses.count)

        XCTAssertFalse(selectedAddresses.contains("community0"))
        XCTAssertFalse(selectedAddresses.contains("community1"))
    }

    private struct Module {
        let presenter: SelectValidatorsStartPresenter
        let view: MockSelectValidatorsStartViewProtocol
        let wireframe: MockSelectValidatorsStartWireframeProtocol
    }

    private func makeModule(
        chain: ChainModel,
        initialTargets: [SelectedValidatorInfo]?,
        allValidators: [ElectedValidatorInfo],
        preferredValidators: [SelectedValidatorInfo]
    ) throws -> Module {
        let view = MockSelectValidatorsStartViewProtocol()
        let wireframe = MockSelectValidatorsStartWireframeProtocol()
        let operationFactory = MockValidatorOperationFactoryProtocol()

        let connection = MockConnection()
        let runtimeService = try RuntimeCodingServiceStub.createWestendService()
        let operationQueue = OperationQueue()

        let interactor = SelectValidatorsStartInteractor(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationFactory: operationFactory,
            maxNominationsOperationFactory: MaxNominationsOperationFactory(operationQueue: operationQueue),
            operationQueue: operationQueue,
            preferredValidatorsProvider: MockPreferredValidatorsProvider(),
            stakingAmount: 0
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            existingStashAddress: nil,
            initialTargets: initialTargets,
            applicationConfig: ApplicationConfig.shared,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        stub(operationFactory) { stub in
            when(stub.allPreferred(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(
                    .init(
                        allElectedValidators: allValidators,
                        notExcludedElectedValidators: allValidators,
                        preferredValidators: preferredValidators
                    )
                )
            }
        }

        return Module(presenter: presenter, view: view, wireframe: wireframe)
    }

    private func performTest(
        for chain: ChainModel,
        selectedTargets: [SelectedValidatorInfo]?,
        allValidators: [ElectedValidatorInfo],
        expectedRecommendedValidators: [ElectedValidatorInfo],
        expectedViewModel: SelectValidatorsStartViewModel,
        expectedCustomValidators: [SelectedValidatorInfo]
    ) throws {
        // given

        let module = try makeModule(
            chain: chain,
            initialTargets: selectedTargets,
            allValidators: allValidators,
            preferredValidators: []
        )

        let view = module.view
        let wireframe = module.wireframe
        let presenter = module.presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceive(viewModel: any())).then { viewModel in
                XCTAssertEqual(viewModel, expectedViewModel)
                setupExpectation.fulfill()
            }
        }

        let generator = CustomValidatorListTestDataGenerator.self

        let recommended = generator
            .createSelectedValidators(from: expectedRecommendedValidators)

        stub(wireframe) { stub in
            when(
                stub.proceedToCustomList(
                    from: any(),
                    selectionValidatorGroups: any(),
                    selectedValidatorList: any(),
                    validatorsSelectionParams: any()
                )
            ).then { _, selectionValidatorGroups, _, _ in
                XCTAssertEqual(
                    expectedCustomValidators.sorted {
                        $0.address.lexicographicallyPrecedes($1.address)
                    },
                    selectionValidatorGroups.fullValidatorList.distinctAll().sorted {
                        $0.address.lexicographicallyPrecedes($1.address)
                    }
                )
            }

            when(stub.proceedToRecommendedList(from: any(), validatorList: any(), maxTargets: any())).then { _, targets, _ in
                XCTAssertEqual(
                    Set(recommended.map(\.address)),
                    Set(targets.map(\.address))
                )
            }
        }

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: 10)

        presenter.selectRecommendedValidators()
        presenter.selectCustomValidators()

        verify(wireframe, times(1)).proceedToCustomList(from: any(), selectionValidatorGroups: any(), selectedValidatorList: any(), validatorsSelectionParams: any())
        verify(wireframe, times(1)).proceedToRecommendedList(from: any(), validatorList: any(), maxTargets: any())
    }
}
