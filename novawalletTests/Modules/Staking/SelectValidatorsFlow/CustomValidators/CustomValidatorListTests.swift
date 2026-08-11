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
            balanceViewModelFactory: balanceViewModelFactory,
            lockedAddresses: [],
            maxNominations: 16
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
            when(stub.setFilterAppliedState(to: any())).then { _ in
                filterExpectation.fulfill()
            }

            when(stub.reload(any(), at: any())).then { viewModel, _ in
                XCTAssertEqual(WestendStub.recommendedValidators.count, viewModel.cellViewModels.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [reloadExpectation, filterExpectation], timeout: Constants.defaultExpectationDuration)
    }

    private func makeLockedPresenter(
        wireframe: MockCustomValidatorListWireframeProtocol,
        selected: [SelectedValidatorInfo],
        locked: [SelectedValidatorInfo],
        community: [SelectedValidatorInfo],
        maxNominations: Int = 16
    ) -> CustomValidatorListPresenter {
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

        let fullValidatorList = CustomValidatorsFullList(
            allValidators: community,
            preferredValidators: locked
        )

        let viewModelFactory = CustomValidatorListViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            lockedAddresses: fullValidatorList.lockedAddresses,
            maxNominations: maxNominations
        )

        let interactor = CustomValidatorListInteractor(
            selectedAsset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactoryStub(priceData: nil),
            currencyManager: CurrencyManagerStub()
        )

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            fullValidatorList: fullValidatorList,
            recommendedValidatorList: community,
            selectedValidatorList: SharedList<SelectedValidatorInfo>(items: selected),
            validatorsSelectionParams: ValidatorsSelectionParams(maxNominations: maxNominations, hasIdentity: true)
        )

        interactor.presenter = presenter

        return presenter
    }

    func testLockedValidatorCannotBeDeselectedByTap() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let community = generator.createSelectedValidators(from: generator.goodValidators)
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let presenter = makeLockedPresenter(
            wireframe: wireframe,
            selected: community + locked,
            locked: locked,
            community: community
        )

        presenter.view = view

        var lastViewModel: CustomValidatorListViewModel?

        stub(view) { stub in
            when(stub.reload(any(), at: any())).then { viewModel, _ in
                lastViewModel = viewModel
            }
            when(stub.setFilterAppliedState(to: any())).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub.present(message: any(), title: any(), closeAction: any(), from: any()))
                .thenDoNothing()
        }

        presenter.setup()

        let lockedIndex = (lastViewModel?.cellViewModels.count ?? 1) - 1
        presenter.changeValidatorSelection(at: lockedIndex)

        // then

        XCTAssertTrue(lastViewModel?.cellViewModels[lockedIndex].isLocked ?? false)
        XCTAssertTrue(lastViewModel?.cellViewModels[lockedIndex].isSelected ?? false)
        XCTAssertEqual(lastViewModel?.selection.lockedSelected, 1)

        let expectedMessage = R.string(
            preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
        ).localizable.stakingCustomLockedValidatorMessage()

        verify(wireframe, times(1)).present(
            message: equal(to: expectedMessage),
            title: any(),
            closeAction: any(),
            from: any()
        )
    }

    func testDeselectAllKeepsLockedValidators() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let community = generator.createSelectedValidators(from: generator.goodValidators)
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let presenter = makeLockedPresenter(
            wireframe: wireframe,
            selected: community + locked,
            locked: locked,
            community: community
        )

        presenter.view = view

        var lastViewModel: CustomValidatorListViewModel?

        stub(view) { stub in
            when(stub.reload(any(), at: any())).then { viewModel, _ in
                lastViewModel = viewModel
            }
            when(stub.setFilterAppliedState(to: any())).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).then { viewModel, _, _ in
                viewModel.actions.first?.handler?()
            }
        }

        presenter.setup()

        // when

        presenter.deselectAll()

        // then

        XCTAssertEqual(lastViewModel?.selection.communitySelected, 0)
        XCTAssertEqual(lastViewModel?.selection.lockedSelected, 1)
        XCTAssertEqual(lastViewModel?.selection.communityLimit, 15)
        XCTAssertEqual(lastViewModel?.selection.totalSelected, 1)
        XCTAssertEqual(lastViewModel?.selection.totalLimit, 16)
    }

    func testSetupDoesNotGrowTheSelection() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let community = generator.createSelectedValidators(from: generator.goodValidators)
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let presenter = makeLockedPresenter(
            wireframe: wireframe,
            selected: community,
            locked: locked,
            community: community
        )

        presenter.view = view

        var lastViewModel: CustomValidatorListViewModel?

        stub(view) { stub in
            when(stub.reload(any(), at: any())).then { viewModel, _ in
                lastViewModel = viewModel
            }
            when(stub.setFilterAppliedState(to: any())).thenDoNothing()
        }

        // when

        presenter.setup()

        XCTAssertEqual(lastViewModel?.selection.communitySelected, community.count)
        XCTAssertEqual(lastViewModel?.selection.lockedSelected, 0)
    }

    func testCountersDoNotChangeWhenAFilterHidesALockedValidator() {
        let generator = CustomValidatorListTestDataGenerator.self
        let community = generator.createSelectedValidators(from: generator.goodValidators)
        let locked = generator.createSelectedValidators(from: [generator.slashedValidator])

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let presenter = makeLockedPresenter(
            wireframe: wireframe,
            selected: community + locked,
            locked: locked,
            community: community
        )

        presenter.view = view

        var lastViewModel: CustomValidatorListViewModel?

        stub(view) { stub in
            when(stub.reload(any(), at: any())).then { viewModel, _ in
                lastViewModel = viewModel
            }
            when(stub.setFilterAppliedState(to: any())).thenDoNothing()
        }

        presenter.setup()

        let stateBefore = lastViewModel?.selection

        // when

        presenter.didUpdate(CustomValidatorListFilter.defaultFilter())

        // then

        XCTAssertEqual(lastViewModel?.selection, stateBefore)
        XCTAssertEqual(lastViewModel?.selection.lockedSelected, 1)

        XCTAssertEqual(lastViewModel?.cellViewModels.filter(\.isLocked).count, 1)
        XCTAssertEqual(lastViewModel?.cellViewModels.last?.isLocked, true)
    }

    func testDidRemoveIgnoresLockedValidator() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let community = generator.createSelectedValidators(from: generator.goodValidators)
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let presenter = makeLockedPresenter(
            wireframe: wireframe,
            selected: community + locked,
            locked: locked,
            community: community
        )

        presenter.view = view

        stub(view) { stub in
            when(stub.reload(any(), at: any())).thenDoNothing()
            when(stub.setFilterAppliedState(to: any())).thenDoNothing()
        }

        presenter.setup()

        // when

        presenter.didRemove(locked[0])

        // then

        XCTAssertTrue(presenter.selectedValidatorList.items.contains { $0.address == locked[0].address })
        XCTAssertEqual(presenter.selectedValidatorList.items.count, community.count + locked.count)
    }

    func testFillWithRecommendedRespectsTheCommunityLimit() {
        // given

        let generator = CustomValidatorListTestDataGenerator.self
        let community = generator.createSelectedValidators(
            from: generator.goodValidators + generator.badValidators
        )
        let locked = generator.createSelectedValidators(from: [generator.clusterValidatorChild1])

        let view = MockCustomValidatorListViewProtocol()
        let wireframe = MockCustomValidatorListWireframeProtocol()

        let presenter = makeLockedPresenter(
            wireframe: wireframe,
            selected: locked,
            locked: locked,
            community: community,
            maxNominations: 3
        )

        presenter.view = view

        var lastViewModel: CustomValidatorListViewModel?

        stub(view) { stub in
            when(stub.reload(any(), at: any())).then { viewModel, _ in
                lastViewModel = viewModel
            }
            when(stub.setFilterAppliedState(to: any())).thenDoNothing()
        }

        presenter.setup()

        // when

        presenter.fillWithRecommended()

        let selection = lastViewModel?.selection
        XCTAssertEqual(selection?.lockedSelected, 1)
        XCTAssertEqual(selection?.communityLimit, 2)
        XCTAssertEqual(selection?.communitySelected, 2)
        XCTAssertEqual(selection?.totalSelected, 3)
        XCTAssertEqual(selection?.totalLimit, 3)
    }
}
