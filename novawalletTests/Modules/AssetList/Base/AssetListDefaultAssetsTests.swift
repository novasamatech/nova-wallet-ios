import XCTest
@testable import novawallet
import Operation_iOS
import Foundation_iOS
import UIKit
import UIKit_iOS

final class AssetListDefaultAssetsTests: XCTestCase {
    func testCachedDefaultsApplyBeforeRemoteOperationCompletes() throws {
        let cachedId = ChainAssetId(chainId: "chain", assetId: 0)
        let remoteId = ChainAssetId(chainId: "chain", assetId: 1)
        let provider = AssetListDefaultsStub(cached: .init(ids: [cachedId]), remote: .success(.init(ids: [remoteId])))
        let interactor = makeInteractor(provider: provider)
        interactor.operationQueue.isSuspended = true
        interactor.setup()
        receiveRows(in: interactor)

        XCTAssertEqual(interactor.visibility?.defaults.ids, [cachedId])
        XCTAssertEqual(interactor.visibility?.isVisible(remoteId), false)

        let refreshed = expectation(description: "Current consumer adopts remote defaults")
        interactor.onVisibility = {
            guard interactor.visibility?.defaults.ids == [remoteId] else { return }
            interactor.onVisibility = nil
            refreshed.fulfill()
        }
        interactor.operationQueue.isSuspended = false
        wait(for: [refreshed], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(interactor.visibility?.isVisible(remoteId), true)
        XCTAssertEqual(interactor.visibility?.isVisible(cachedId), false)
    }

    func testRemoteFailureWithoutCacheUnblocksAllAssets() throws {
        let provider = AssetListDefaultsStub(cached: nil, remote: .failure(CommonError.dataCorruption))
        let interactor = makeInteractor(provider: provider)
        interactor.operationQueue.isSuspended = true
        interactor.setup()
        receiveRows(in: interactor)
        XCTAssertNil(interactor.visibility)

        let resolved = expectation(description: "Failed config unblocks visibility")
        interactor.onVisibility = {
            interactor.onVisibility = nil
            resolved.fulfill()
        }
        interactor.operationQueue.isSuspended = false
        wait(for: [resolved], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(interactor.visibility?.isVisible(.init(chainId: "any", assetId: 0)), true)
    }

    func testVisibilitySubscriptionFailureUnblocksEvenWhileConfigIsPending() {
        let provider = AssetListDefaultsStub(cached: nil, remote: .success(.init(ids: [.init(chainId: "chain", assetId: 0)])))
        let interactor = makeInteractor(provider: provider)
        interactor.operationQueue.isSuspended = true
        defer { interactor.operationQueue.isSuspended = false }
        interactor.setup()

        interactor.handleAssetVisibility(
            result: .failure(CommonError.dataCorruption),
            metaId: interactor.selectedWalletSettings.value.metaId
        )

        XCTAssertEqual(interactor.visibility?.isVisible(.init(chainId: "any", assetId: 0)), true)
    }

    func testAssetListKeepsCollectionVisibleWhileLoading() {
        let layout = makeController().rootView

        XCTAssertFalse(layout.collectionView.isHidden)
        XCTAssertFalse(layout.subviews.contains { $0 is LoadingView })
    }

    func testResolvedVisibilityShowsLoaderOnlyInTokensSectionWhileAssetGroupsAreEmpty() throws {
        let controller = makeController()

        controller.didReceiveGroups(
            viewModel: .init(
                hasHiddenAssets: false,
                listState: .list(groups: []),
                listGroupStyle: .tokens
            )
        )

        let collectionView = controller.rootView.collectionView

        XCTAssertFalse(collectionView.isHidden)
        XCTAssertEqual(
            collectionView.numberOfItems(inSection: AssetListFlowLayout.SectionType.settings.index),
            2
        )
        XCTAssertEqual(
            collectionView.numberOfItems(inSection: collectionView.numberOfSections - 1),
            0
        )

        let loadingCell = try XCTUnwrap(
            collectionView.dataSource?.collectionView(
                collectionView,
                cellForItemAt: AssetListFlowLayout.CellType.loadingState.indexPath
            ) as? AssetListLoadingCell
        )

        XCTAssertNotNil(loadingCell.loadingView.indicatorImage)
        XCTAssertTrue(loadingCell.loadingView.isAnimating)
        XCTAssertFalse(loadingCell.contentView.subviews.contains { $0 is UIActivityIndicatorView })
    }

    func testUnresolvedVisibilityShowsLoaderInsteadOfProvisionalAssetGroups() {
        let controller = makeController()

        controller.didReceiveGroups(
            viewModel: .init(
                hasHiddenAssets: nil,
                listState: .list(groups: [makeTokenGroup()]),
                listGroupStyle: .tokens
            )
        )

        let collectionView = controller.rootView.collectionView

        XCTAssertFalse(collectionView.isHidden)
        XCTAssertEqual(
            collectionView.numberOfSections,
            AssetListFlowLayout.SectionType.sectionsCount(groupsCount: 0)
        )
        XCTAssertEqual(
            collectionView.numberOfItems(inSection: AssetListFlowLayout.SectionType.settings.index),
            2
        )
    }

    func testAssetGroupsReplaceLoaderAfterVisibilityResolves() {
        let controller = makeController()

        controller.didReceiveGroups(
            viewModel: .init(
                hasHiddenAssets: false,
                listState: .list(groups: [makeTokenGroup()]),
                listGroupStyle: .tokens
            )
        )

        let collectionView = controller.rootView.collectionView

        XCTAssertEqual(
            collectionView.numberOfSections,
            AssetListFlowLayout.SectionType.sectionsCount(groupsCount: 1)
        )
        XCTAssertEqual(
            collectionView.numberOfItems(inSection: AssetListFlowLayout.SectionType.settings.index),
            1
        )
    }

    func testExplicitEmptyStateReplacesLoaderAfterVisibilityResolves() throws {
        let controller = makeController()

        controller.didReceiveGroups(
            viewModel: .init(
                hasHiddenAssets: false,
                listState: .empty,
                listGroupStyle: .tokens
            )
        )

        let collectionView = controller.rootView.collectionView

        XCTAssertEqual(
            collectionView.numberOfItems(inSection: AssetListFlowLayout.SectionType.settings.index),
            2
        )
        XCTAssertEqual(
            collectionView.numberOfItems(inSection: collectionView.numberOfSections - 1),
            1
        )

        let stateCell = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: AssetListFlowLayout.CellType.emptyState.indexPath
        )

        XCTAssertTrue(try XCTUnwrap(stateCell) is AssetListEmptyCell)
    }

    func testRecoveredVisibilityRowsApplyWhileConfigurationRemainsPending() {
        let defaultId = ChainAssetId(chainId: "chain", assetId: 0)
        let otherId = ChainAssetId(chainId: "chain", assetId: 1)
        let provider = AssetListDefaultsStub(cached: nil, remote: .success(.init(ids: [defaultId])))
        let interactor = makeInteractor(provider: provider)
        interactor.operationQueue.isSuspended = true
        interactor.setup()
        let metaId = interactor.selectedWalletSettings.value.metaId
        interactor.handleAssetVisibility(result: .failure(CommonError.dataCorruption), metaId: metaId)
        XCTAssertEqual(interactor.visibility?.isVisible(defaultId), true)

        let hidden = AssetVisibilityLocal(
            metaId: metaId,
            chainId: defaultId.chainId,
            assetId: defaultId.assetId,
            state: .hidden
        )
        interactor.handleAssetVisibility(result: .success([.insert(newItem: hidden)]), metaId: metaId)

        XCTAssertEqual(interactor.visibility?.isVisible(defaultId), false)
        XCTAssertEqual(interactor.visibility?.isVisible(otherId), true)

        let refreshed = expectation(description: "Remote defaults replace fallback while preserving recovered rows")
        interactor.onVisibility = {
            guard interactor.visibility?.defaults.ids == [defaultId] else { return }
            interactor.onVisibility = nil
            refreshed.fulfill()
        }
        interactor.operationQueue.isSuspended = false
        wait(for: [refreshed], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(interactor.visibility?.isVisible(defaultId), false)
        XCTAssertEqual(interactor.visibility?.isVisible(otherId), false)
    }

    func testVisibilityRecoveryRetainsPreviouslyReceivedUserPreferences() {
        let id = ChainAssetId(chainId: "chain", assetId: 0)
        let provider = AssetListDefaultsStub(cached: .init(ids: [id]), remote: .success(.init(ids: [id])))
        let interactor = makeInteractor(provider: provider)
        interactor.operationQueue.isSuspended = true
        defer { interactor.operationQueue.isSuspended = false }
        interactor.setup()
        let metaId = interactor.selectedWalletSettings.value.metaId
        let row = AssetVisibilityLocal(metaId: metaId, chainId: id.chainId, assetId: id.assetId, state: .hidden)
        interactor.handleAssetVisibility(result: .success([.insert(newItem: row)]), metaId: metaId)

        interactor.handleAssetVisibility(result: .failure(CommonError.dataCorruption), metaId: metaId)
        XCTAssertEqual(interactor.visibility?.isVisible(id), true)

        interactor.handleAssetVisibility(result: .success([]), metaId: metaId)
        XCTAssertEqual(interactor.visibility?.isVisible(id), false)
    }
}

private extension AssetListDefaultAssetsTests {
    func makeController() -> AssetListViewController {
        let controller = AssetListViewController(
            presenter: AssetListPresenterStub(),
            bannersViewProvider: EmptyBannersViewProvider(),
            localizationManager: LocalizationManager.shared
        )
        controller.loadViewIfNeeded()

        return controller
    }

    func makeTokenGroup() -> AssetListGroupType {
        let balance = AssetListAssetBalanceViewModel(
            price: .loading,
            balanceAmount: .loading,
            balanceValue: .loading
        )

        return .token(
            .init(
                token: .init(symbol: "DOT", imageViewModel: nil),
                assets: [],
                balance: balance
            )
        )
    }

    func makeInteractor(provider: DefaultAssetsProviding) -> VisibilityRecordingInteractor {
        let queue = OperationQueue()
        let storage = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: queue)
        settings.internalValue = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let registry = MockChainRegistryProtocol().applyDefault(for: [])

        return VisibilityRecordingInteractor(
            selectedWalletSettings: settings,
            chainRegistry: registry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryStub(),
            externalBalancesSubscriptionFactory: EmptyExternalBalancesFactory(),
            priceLocalSubscriptionFactory: PriceProviderFactoryStub(),
            assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactory(
                chainRegistry: registry,
                storageFacade: storage,
                operationManager: OperationManager(operationQueue: queue),
                logger: Logger.shared
            ),
            defaultAssetsProvider: provider,
            operationQueue: queue,
            currencyManager: CurrencyManagerStub()
        )
    }

    func receiveRows(in interactor: AssetListBaseInteractor) {
        interactor.handleAssetVisibility(result: .success([]), metaId: interactor.selectedWalletSettings.value.metaId)
    }
}

private final class VisibilityRecordingInteractor: AssetListBaseInteractor {
    var onVisibility: (() -> Void)?

    override func subscribeChains() {}

    override func didResolveVisibility(hasHiddenAssets _: Bool) {
        onVisibility?()
    }
}

private struct AssetListDefaultsStub: DefaultAssetsProviding {
    let cached: DefaultAssetsList?
    let remote: Result<DefaultAssetsList, Error>

    var cachedDefaultAssets: DefaultAssetsList? { cached }

    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        if let cached { return .createWithResult(cached) }
        return createRefreshDefaultAssetsWrapper()
    }

    func createRefreshDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { try remote.get() })
    }
}

private struct EmptyExternalBalancesFactory: ExternalBalanceLocalSubscriptionFactoryProtocol {
    func getExternalAssetBalanceProvider(
        for _: AccountId,
        chainAsset _: ChainAsset
    ) -> StreamableProvider<ExternalAssetBalance>? { nil }

    func getAllExternalAssetBalanceProvider() -> StreamableProvider<ExternalAssetBalance>? { nil }
}

private final class EmptyBannersViewProvider: UIViewController, BannersViewProviderProtocol {
    func getMaxBannerHeight() -> CGFloat { 0 }
}

private final class AssetListPresenterStub: AssetListPresenterProtocol {
    func setup() {}
    func selectWallet() {}
    func selectOrganizerItem(at _: Int) {}
    func selectAsset(for _: ChainAssetId) {}
    func refresh() {}
    func presentSearch() {}
    func presentAssetsManage() {}
    func presentLocks() {}
    func presentCard() {}
    func send() {}
    func receive() {}
    func buySell() {}
    func swap() {}
    func gift() {}
    func presentWalletConnect() {}
    func toggleAssetListStyle() {}
    func togglePrivacyMode() {}
    func presentLearnMore(_: InlinableAlertView.Model.AlertType) {}
}
