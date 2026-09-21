import Foundation_iOS
import UIKit

private struct SubtensorStakingChartAnimationState {
    private var initialSelectionIndex: Int?
    private var hasAnimatedInitialSelection = false

    mutating func captureInitialSelection(index: Int) {
        guard initialSelectionIndex == nil else {
            return
        }

        initialSelectionIndex = index
    }

    mutating func shouldAnimateChart(at index: Int) -> Bool {
        guard
            index == initialSelectionIndex,
            !hasAnimatedInitialSelection
        else {
            return false
        }

        hasAnimatedInitialSelection = true
        return true
    }
}

final class SubtensorStakingStrategiesViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorStakingStrategiesViewLayout

    let presenter: SubtensorStakingStrategiesPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    private var viewModel: SubtensorStakingStrategiesViewModel?
    private var selectedIndex = 0
    private var chartAnimationState = SubtensorStakingChartAnimationState()
    private var lastCollectionViewWidth: CGFloat = 0

    init(
        presenter: SubtensorStakingStrategiesPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorStakingStrategiesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        setupActions()
        rootView.setLoading(true)
        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let collectionViewWidth = rootView.collectionView.bounds.width

        guard
            collectionViewWidth > 0,
            collectionViewWidth != lastCollectionViewWidth
        else {
            return
        }

        lastCollectionViewWidth = collectionViewWidth
        rootView.collectionView.collectionViewLayout.invalidateLayout()
        scrollToSelectedIndex(animated: false)
    }
}

private extension SubtensorStakingStrategiesViewController {
    func setupCollectionView() {
        rootView.collectionView.registerCellClass(SubtensorStakingStrategyCell.self)
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
    }

    func setupActions() {
        rootView.previousButton.addTarget(
            self,
            action: #selector(actionPrevious),
            for: .touchUpInside
        )
        rootView.nextButton.addTarget(
            self,
            action: #selector(actionNext),
            for: .touchUpInside
        )
    }

    func scrollToSelectedIndex(animated: Bool) {
        guard
            let viewModel,
            viewModel.cards.indices.contains(selectedIndex),
            rootView.collectionView.bounds.width > 0
        else {
            return
        }

        rootView.collectionView.scrollToItem(
            at: IndexPath(item: selectedIndex, section: 0),
            at: .centeredHorizontally,
            animated: animated && !UIAccessibility.isReduceMotionEnabled
        )

        updateVisibleCardAppearance()

        if !animated || UIAccessibility.isReduceMotionEnabled {
            rootView.collectionView.layoutIfNeeded()
            animateSelectedChartIfNeeded()
        }
    }

    func updateVisibleCardAppearance() {
        guard let layout = rootView.collectionView.collectionViewLayout
            as? SubtensorStakingStrategiesCarouselLayout else {
            return
        }

        for cell in rootView.collectionView.visibleCells {
            let progress = layout.inactiveProgress(forItemCenterX: cell.center.x)
            (cell as? SubtensorStakingStrategyCell)?.setInactiveProgress(progress)
        }
    }

    func updateSelectedPageFromScroll() {
        guard let viewModel, !viewModel.cards.isEmpty else {
            return
        }

        let visibleCenterX = rootView.collectionView.bounds.midX
        let visibleRect = CGRect(
            origin: rootView.collectionView.contentOffset,
            size: rootView.collectionView.bounds.size
        )

        guard let index = rootView.collectionView.collectionViewLayout
            .layoutAttributesForElements(in: visibleRect)?
            .min(by: {
                abs($0.center.x - visibleCenterX) < abs($1.center.x - visibleCenterX)
            })?
            .indexPath.item else {
            return
        }

        presenter.select(index: min(max(index, 0), viewModel.cards.count - 1))
    }

    func animateSelectedChartIfNeeded() {
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        let cell = rootView.collectionView.cellForItem(at: indexPath) as? SubtensorStakingStrategyCell
        animateChartIfNeeded(in: cell, at: indexPath)
    }

    func animateChartIfNeeded(
        in cell: SubtensorStakingStrategyCell?,
        at indexPath: IndexPath
    ) {
        guard
            indexPath.item == selectedIndex,
            let cell,
            chartAnimationState.shouldAnimateChart(at: indexPath.item)
        else {
            return
        }

        cell.animateChartAppearance()
    }

    @objc func actionPrevious() {
        presenter.selectPrevious()
    }

    @objc func actionNext() {
        presenter.selectNext()
    }
}

extension SubtensorStakingStrategiesViewController: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModel?.cards.count ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(
            SubtensorStakingStrategyCell.self,
            for: indexPath
        )!

        guard let viewModel else {
            return cell
        }

        cell.bind(
            viewModel: viewModel.cards[indexPath.item],
            chooseTitle: "Choose"
        )
        cell.setInactiveProgress(indexPath.item == selectedIndex ? 0 : 1)
        cell.onChoose = { [weak self] in
            self?.presenter.select(index: indexPath.item)
            self?.presenter.chooseSelected()
        }

        return cell
    }
}

extension SubtensorStakingStrategiesViewController: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        animateChartIfNeeded(
            in: cell as? SubtensorStakingStrategyCell,
            at: indexPath
        )
    }

    func scrollViewDidScroll(_: UIScrollView) {
        updateVisibleCardAppearance()
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        updateSelectedPageFromScroll()
        animateSelectedChartIfNeeded()
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else {
            return
        }

        updateSelectedPageFromScroll()
        animateSelectedChartIfNeeded()
    }

    func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        animateSelectedChartIfNeeded()
    }
}

extension SubtensorStakingStrategiesViewController: SubtensorStakingStrategiesViewProtocol {
    func didReceive(viewModel: LoadableViewModelState<SubtensorStakingStrategiesViewModel>) {
        switch viewModel {
        case .loading:
            rootView.setLoading(true)
        case let .cached(value), let .loaded(value):
            self.viewModel = value
            title = value.title
            rootView.disclaimerLabel.text = value.disclaimer
            rootView.pageControl.numberOfPages = value.cards.count
            rootView.collectionView.reloadData()
            rootView.setLoading(false)
            rootView.updateSelection(index: selectedIndex, count: value.cards.count)
        }
    }

    func didReceive(selectedIndex: Int, animated: Bool) {
        chartAnimationState.captureInitialSelection(index: selectedIndex)
        self.selectedIndex = selectedIndex

        let layout = rootView.collectionView.collectionViewLayout
            as? SubtensorStakingStrategiesCarouselLayout
        layout?.selectedIndex = selectedIndex

        let count = viewModel?.cards.count ?? 0
        rootView.updateSelection(index: selectedIndex, count: count)
        scrollToSelectedIndex(animated: animated)
    }
}

extension SubtensorStakingStrategiesViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }

        presenter.refreshContent()
    }
}
