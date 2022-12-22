import UIKit
import SoraUI
import RobinHood
import SoraFoundation
import CommonWallet

final class TransactionHistoryViewController: UIViewController, ViewHolder, EmptyStateViewOwnerProtocol {
    var presentationNavigationItem: UINavigationItem? {
        navigationController != nil ? navigationItem : nil
    }

    var emptyStateDelegate: EmptyStateDelegate {
        self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        emptyDatasource
    }

    weak var delegate: DraggableDelegate?
    typealias RootViewType = TransactionHistoryViewLayout
    private var dataSource: TransactionHistoryDataSource?

    let presenter: TransactionHistoryPresenterProtocol
    private var draggableState: DraggableState = .compact
    private var didSetupLayout: Bool = false
    private let emptyDatasource = WalletEmptyStateDataSource.history
    private var fullInsets: UIEdgeInsets = .zero

    private var viewModel: [TransactionSectionModel] = []
    private var isLoading: Bool = false

    private var compactInsets: UIEdgeInsets = .zero {
        didSet {
            if compactInsets != oldValue {
                updateEmptyStateInsets()
            }
        }
    }

    init(presenter: TransactionHistoryPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TransactionHistoryViewLayout()
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
        dataSource = TransactionHistoryDataSource(tableView: rootView.tableView)
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
        rootView.filterButton.addTarget(self, action: #selector(didTapOnFilter), for: .touchUpInside)
    }

    @objc private func didTapOnFilter() {
        presenter.showFilter()
    }

    private func update(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        updateContent(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
        updateHeaderHeight(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
    }

    private func updateTableViewAfterTransition(to: DraggableState, animated: Bool) {
        updateTableViewContentOffset(to: to, animated: animated)
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.walletHistoryTitle_v190(
            preferredLanguages: languages
        )
    }

    func updateHeaderHeight(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        let cornerRadius = Constants.cornerRadius

        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)

            let headerTopOffset = CGFloat(1.0 - adjustedProgress) * (fullInsets.top - cornerRadius) + cornerRadius
            let headerHeightOffset = Constants.headerHeight * CGFloat(adjustedProgress) + fullInsets.top * CGFloat(1.0 - adjustedProgress)
            rootView.headerTop?.update(offset: headerTopOffset)
            rootView.headerHeight?.update(offset: headerHeightOffset)
        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)

            let headerTopOffset = CGFloat(adjustedProgress) * (fullInsets.top - cornerRadius) + cornerRadius
            let headerHeightOffset = Constants.headerHeight * CGFloat(1.0 - adjustedProgress) + fullInsets.top * CGFloat(adjustedProgress)
            rootView.headerTop?.update(offset: headerTopOffset)
            rootView.headerHeight?.update(offset: headerHeightOffset)
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
            let adjustedBackgroundProgress = min((1 - (1 - progress)) / Constants.triggerProgressThreshold, 1.0)
            let backgroundProgress = adjustedBackgroundProgress

            rootView.backgroundView.applyFullscreen(progress: backgroundProgress)
            rootView.closeButton.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(adjustedProgress)

            let titleProgress = CGFloat(1.0 - adjustedProgress) * (titleFullPosition - titleCompactPosition)
            rootView.titleLeft?.update(inset: titleCompactPosition + titleProgress)

            if progress > 0.0 {
                rootView.tableView.isScrollEnabled = false
            }

        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)
            let backgroundProgress = min(progress * Constants.triggerBackgroundProgressThreshold * 100, 1)
            rootView.backgroundView.applyFullscreen(progress: CGFloat(1.0 - backgroundProgress))
            rootView.closeButton.alpha = CGFloat(adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(1.0 - adjustedProgress)

            let titleProgress = CGFloat(adjustedProgress) * (titleFullPosition - titleCompactPosition)
            rootView.titleLeft?.update(inset: titleCompactPosition + titleProgress)
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
    }

    func animate(progress: Double, from _: DraggableState, to newState: DraggableState, finalFrame: CGRect) {
        UIView.beginAnimations(nil, context: nil)

        draggableView.frame = finalFrame
        updateHeaderHeight(for: newState, progress: progress, forcesLayoutUpdate: didSetupLayout)
        updateContent(for: newState, progress: progress, forcesLayoutUpdate: didSetupLayout)

        UIView.commitAnimations()
    }
}

extension TransactionHistoryViewController: TransactionHistoryViewProtocol {
    func startLoading() {
        rootView.pageLoadingView.start()
        isLoading = true
    }

    func stopLoading() {
        rootView.pageLoadingView.stop()
        isLoading = false
    }

    func didReceive(viewModel: [TransactionSectionModel]) {
        isLoading = false
        self.viewModel = viewModel
        var snapshot = NSDiffableDataSourceSnapshot<TransactionSectionModel, TransactionItemViewModel>()
        snapshot.appendSections(viewModel)
        viewModel.forEach { section in
            snapshot.appendItems(section.items, toSection: section)
        }
        dataSource?.apply(snapshot, animatingDifferences: true)
        reloadEmptyState(animated: false)
    }
}

extension TransactionHistoryViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.cellHeight
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        Constants.sectionHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = viewModel[indexPath.section].items[indexPath.row]
        presenter.select(item: item)
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let dataSource = dataSource else {
            return nil
        }
        let headerView: TransactionHistoryHeaderView = .init(frame: .zero)
        headerView.bind(title: dataSource.snapshot().sectionIdentifiers[section].title)

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

extension TransactionHistoryViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        dataSource?.snapshot().numberOfSections == 0 && isLoading == false
    }
}

extension TransactionHistoryViewController {
    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let cellHeight: CGFloat = 56.0
        static let headerHeight: CGFloat = 45.0
        static let sectionHeight: CGFloat = 44.0
        static let multiplierToActivateNextLoading: CGFloat = 1.5
        static let draggableProgressFinal: Double = 1.0
        static let triggerProgressThreshold: Double = 0.8
        static let bouncesThreshold: CGFloat = 1.0
        static let triggerBackgroundProgressThreshold: Double = 1 - triggerProgressThreshold
    }
}
