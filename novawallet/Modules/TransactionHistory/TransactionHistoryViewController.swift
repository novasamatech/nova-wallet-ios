import UIKit
import UIKit_iOS
import Operation_iOS
import Foundation_iOS

private struct NavigationItemState {
    var title: String?
    var leftBarItem: UIBarButtonItem?
    var rightBarItem: UIBarButtonItem?
}

final class TransactionHistoryViewController: UIViewController, ViewHolder, EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        self
    }

    weak var delegate: DraggableDelegate?
    typealias RootViewType = TransactionHistoryViewLayout
    private var dataSource: TransactionHistoryDataSource?

    let presenter: TransactionHistoryPresenterProtocol
    let supportsFilters: Bool

    private var draggableState: DraggableState = .compact
    private var didSetupLayout: Bool = false
    private let walletEmptyStateDataSource = WalletEmptyStateDataSource.history
    private var fullInsets: UIEdgeInsets = .zero
    private var originNavigationItemState: NavigationItemState?
    private var cleanNavigationItemState: NavigationItemState = .init(leftBarItem: .init())

    private var viewModel: [TransactionHistorySectionModel] = []
    private var isLoading: Bool = false

    private var compactInsets: UIEdgeInsets = .zero {
        didSet {
            if compactInsets != oldValue {
                updateEmptyStateInsets()
            }
        }
    }

    init(
        presenter: TransactionHistoryPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        supportsFilters: Bool
    ) {
        self.presenter = presenter
        self.supportsFilters = supportsFilters

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TransactionHistoryViewLayout(frame: .zero, supportsFilters: supportsFilters)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        update(
            for: draggableState,
            progress: Constants.draggableProgressFinal,
            forcesLayoutUpdate: false
        )
        updateTableViewAfterTransition(
            to: draggableState,
            animated: false
        )

        applyContentInsets(for: draggableState)
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(HistoryItemTableViewCell.self)
        rootView.tableView.registerClassForCell(HistoryAHMTableViewCell.self)

        dataSource = TransactionHistoryDataSource(
            tableView: rootView.tableView,
            ahmHintViewDelegate: self
        )
        rootView.tableView.dataSource = dataSource

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        didSetupLayout = true
    }

    private func setupHandlers() {
        if supportsFilters {
            rootView.filterButton.addTarget(self, action: #selector(didTapOnFilter), for: .touchUpInside)
        }
    }

    @objc private func didTapOnFilter() {
        presenter.showFilter()
    }

    @objc private func didTapOnClose() {
        if draggableState == .full {
            delegate?.wantsTransit(to: .compact, animating: true)
        }
    }

    private func update(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        updateContent(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
        updateHeaderHeight(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
    }

    private func updateTableViewAfterTransition(to state: DraggableState, animated: Bool) {
        updateTableViewContentOffset(to: state, animated: animated)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.walletHistoryTitle_v190()
    }

    private func updateHeaderHeight(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        let cornerRadius = 0.0
        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)
            let headerHeight = Constants.headerCompactHeight * CGFloat(adjustedProgress) +
                fullInsets.top * CGFloat(1.0 - adjustedProgress)
            rootView.headerHeight?.update(offset: headerHeight)
        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)

            let headerTop = CGFloat(1.0 - adjustedProgress) *
                (fullInsets.top * CGFloat(adjustedProgress) - cornerRadius) + cornerRadius
            let headerHeight = Constants.headerCompactHeight * CGFloat(1.0 - adjustedProgress) +
                fullInsets.top * CGFloat(adjustedProgress)
            rootView.headerHeight?.update(offset: headerHeight)
            rootView.headerTop?.update(offset: headerTop + 16)
        }

        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    func updateContent(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        let titleFullPosition = rootView.headerView.bounds.midX - rootView.titleLabel.intrinsicContentSize.width / 2.0
        let titleCompactPosition = RootViewType.Constants.titleLeftCompactInset

        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)
            let backgroundProgress = max(
                (progress - 1 + Constants.triggerProgressThreshold) / Constants.triggerProgressThreshold, 0
            )

            rootView.backgroundView.applyFullscreen(progress: 1 - backgroundProgress)
            rootView.closeButton.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(adjustedProgress)

            let titleProgress = CGFloat(1.0 - adjustedProgress) * (titleFullPosition - titleCompactPosition)
            rootView.titleLeft?.update(inset: titleCompactPosition + titleProgress)
            rootView.headerView.alpha = CGFloat(adjustedProgress)
            if progress > 0.0 {
                rootView.tableView.isScrollEnabled = false
            }
        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)
            let backgroundProgress = min(progress / Constants.triggerBackgroundProgressThreshold, 1)
            rootView.backgroundView.applyFullscreen(progress: backgroundProgress)
            rootView.closeButton.alpha = CGFloat(adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(1.0 - adjustedProgress)

            let titleProgress = CGFloat(adjustedProgress) * (titleFullPosition - titleCompactPosition)
            rootView.titleLeft?.update(inset: titleCompactPosition + titleProgress)
            rootView.headerView.alpha = CGFloat(1.0 - adjustedProgress)
        }
        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    func updateTableViewContentOffset(
        to state: DraggableState,
        animated: Bool
    ) {
        switch state {
        case .compact:
            rootView.tableView.setContentOffset(.zero, animated: animated)
            rootView.tableView.showsVerticalScrollIndicator = false
        case .full:
            rootView.tableView.isScrollEnabled = true
        }
    }

    private func updateNavigationItem(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        switch draggableState {
        case .compact:
            if progress > Constants.navigationItemThreshold, progress < 1 - Constants.triggerProgressThreshold {
                setNavigationItem(state: cleanNavigationItemState)
            }
            if progress >= 1 - Constants.triggerProgressThreshold {
                setNavigationItem(state: originNavigationItemState)
            }
        case .full:
            break
        }

        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    private func updateNavigationItem(for state: DraggableState) {
        switch state {
        case .compact:
            if let state = originNavigationItemState {
                setNavigationItem(state: state)
            }
        case .full:
            let closeBarItem = UIBarButtonItem(
                image: rootView.closeIcon,
                style: .plain,
                target: self,
                action: #selector(didTapOnClose)
            )

            let filterItem: UIBarButtonItem?

            if supportsFilters {
                filterItem = UIBarButtonItem(
                    image: rootView.filterIcon,
                    style: .plain,
                    target: self,
                    action: #selector(didTapOnFilter)
                )
            } else {
                filterItem = nil
            }

            let state = NavigationItemState(
                title: rootView.titleLabel.text,
                leftBarItem: closeBarItem,
                rightBarItem: filterItem
            )

            setNavigationItem(state: state)
        }
    }

    private func setNavigationItem(state: NavigationItemState?) {
        guard let state = state,
              let navigationItem = delegate?.presentationNavigationItem else {
            return
        }
        navigationItem.title = state.title
        navigationItem.leftBarButtonItem = state.leftBarItem
        navigationItem.rightBarButtonItem = state.rightBarItem
    }

    func applyContentInsets(for draggableState: DraggableState) {
        switch draggableState {
        case .compact:
            rootView.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: compactInsets.bottom, right: 0)
        default:
            rootView.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: fullInsets.bottom, right: 0)
        }
    }

    func set(contentInsets: UIEdgeInsets, for state: DraggableState) {
        switch state {
        case .compact:
            compactInsets = contentInsets
        case .full:
            fullInsets = contentInsets
        }

        if draggableState == state {
            applyContentInsets(for: draggableState)
            update(for: draggableState, progress: Constants.draggableProgressFinal, forcesLayoutUpdate: didSetupLayout)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isLoading {
            rootView.pageLoadingView.start()
        }
    }
}

extension TransactionHistoryViewController: Draggable {
    var draggableView: UIView {
        rootView
    }

    var scrollPanRecognizer: UIPanGestureRecognizer? {
        rootView.tableView.panGestureRecognizer
    }

    func canDrag(from state: DraggableState) -> Bool {
        switch state {
        case .compact:
            return true
        case .full:
            return !(rootView.tableView.contentOffset.y > 0.0)
        }
    }

    func set(dragableState: DraggableState, animated: Bool) {
        let oldState = dragableState
        draggableState = dragableState

        if animated {
            animate(
                progress: Constants.draggableProgressFinal,
                from: oldState,
                to: dragableState,
                finalFrame: draggableView.frame
            )
        } else {
            update(for: dragableState, progress: Constants.draggableProgressFinal, forcesLayoutUpdate: didSetupLayout)
        }

        updateTableViewAfterTransition(to: dragableState, animated: animated)
        updateNavigationItem(for: dragableState)
    }

    func animate(progress: Double, from _: DraggableState, to newState: DraggableState, finalFrame: CGRect) {
        UIView.beginAnimations(nil, context: nil)

        if originNavigationItemState == nil, let presentationNavigationItem = delegate?.presentationNavigationItem {
            originNavigationItemState = .init(
                title: presentationNavigationItem.title,
                leftBarItem: presentationNavigationItem.leftBarButtonItem,
                rightBarItem: presentationNavigationItem.rightBarButtonItem
            )
        }
        draggableView.frame = finalFrame
        updateHeaderHeight(for: newState, progress: progress, forcesLayoutUpdate: didSetupLayout)
        updateContent(for: newState, progress: progress, forcesLayoutUpdate: didSetupLayout)
        updateNavigationItem(
            for: newState,
            progress: progress,
            forcesLayoutUpdate: didSetupLayout
        )
        UIView.commitAnimations()
    }
}

extension TransactionHistoryViewController: TransactionHistoryViewProtocol {
    func startLoading() {
        rootView.pageLoadingView.start()
        isLoading = true
        reloadEmptyState(animated: false)
    }

    func stopLoading() {
        rootView.pageLoadingView.stop()
        isLoading = false
        reloadEmptyState(animated: false)
    }

    func didReceive(viewModel: [TransactionHistorySectionModel]) {
        self.viewModel = viewModel
        var snapshot = NSDiffableDataSourceSnapshot<TransactionHistorySectionModel, TransactionHistoryItemModel>()
        snapshot.appendSections(viewModel)
        viewModel.forEach { section in
            switch section {
            case let .ahmHint(item):
                snapshot.appendItems([item], toSection: section)
            case let .transaction(sectionModel):
                snapshot.appendItems(sectionModel.items, toSection: section)
            }
        }
        dataSource?.apply(snapshot, animatingDifferences: false)
        reloadEmptyState(animated: false)
    }
}

extension TransactionHistoryViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.cellHeight
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard case .transaction = dataSource?.snapshot().sectionIdentifiers[section] else {
            return .zero
        }

        return Constants.sectionHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = viewModel[indexPath.section]

        switch section {
        case let .transaction(sectionModel):
            guard case let .transaction(item) = sectionModel.items[indexPath.row] else {
                return
            }
            presenter.select(item: item)
        case .ahmHint:
            break
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .transaction(sectionModel) = dataSource?.snapshot().sectionIdentifiers[section] else {
            return nil
        }

        let headerView: TransactionHistoryHeaderView = .init(frame: .zero)
        headerView.bind(title: sectionModel.title)

        return headerView
    }
}

extension TransactionHistoryViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        handleDraggableOnScroll(scrollView: scrollView)
        handleNextPageOnScroll(scrollView: scrollView)
    }

    private func handleDraggableOnScroll(scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < Constants.bouncesThreshold {
            scrollView.bounces = false
            scrollView.showsVerticalScrollIndicator = false
        } else {
            scrollView.bounces = true
            scrollView.showsVerticalScrollIndicator = true
        }
    }

    private func handleNextPageOnScroll(scrollView: UIScrollView) {
        var threshold = scrollView.contentSize.height
        threshold -= scrollView.bounds.height * Constants.multiplierToActivateNextLoading

        if scrollView.contentOffset.y > threshold {
            presenter.loadNext()
        }
    }
}

extension TransactionHistoryViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            reloadEmptyState(animated: false)
            view.setNeedsLayout()
        }
    }
}

extension TransactionHistoryViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        nil
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }

    var imageForEmptyState: UIImage? {
        walletEmptyStateDataSource.imageForEmptyState
    }

    var titleForEmptyState: String? {
        walletEmptyStateDataSource.titleForEmptyState
    }

    var titleColorForEmptyState: UIColor? {
        walletEmptyStateDataSource.titleColorForEmptyState
    }

    var titleFontForEmptyState: UIFont? {
        walletEmptyStateDataSource.titleFontForEmptyState
    }

    var verticalSpacingForEmptyState: CGFloat? {
        walletEmptyStateDataSource.verticalSpacingForEmptyState
    }

    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        walletEmptyStateDataSource.trimStrategyForEmptyState
    }
}

extension TransactionHistoryViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        dataSource?.snapshot().numberOfSections == 0 && isLoading == false
    }
}

// MARK: - HistoryAHMViewDelegate

extension TransactionHistoryViewController: HistoryAHMViewDelegate {
    func didActionViewRelay() {
        presenter.actionViewRelay()
    }
}

extension TransactionHistoryViewController {
    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let cellHeight: CGFloat = 56.0
        static let headerCompactHeight: CGFloat = 42
        static let headerFullHeight: CGFloat = 98
        static let sectionHeight: CGFloat = 37.0
        static let multiplierToActivateNextLoading: CGFloat = 1.5
        static let draggableProgressFinal: Double = 1.0
        static let triggerProgressThreshold: Double = 0.8
        static let navigationItemThreshold: Double = 0.01
        static let bouncesThreshold: CGFloat = 1.0
        static let triggerBackgroundProgressThreshold: Double = 1 - triggerProgressThreshold
    }
}
