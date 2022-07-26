import UIKit
import SoraFoundation
import SoraUI

final class ParaStkYourCollatorsViewController: UIViewController, ViewHolder {
    private enum Constants {
        static let warningHeaderMargins = UIEdgeInsets(
            top: 8.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )

        static let regularHeaderMargins = UIEdgeInsets(
            top: 8.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )

        static let notTopStatusHeaderMargins = UIEdgeInsets(
            top: 20.0,
            left: 0.0,
            bottom: 8.0,
            right: 0.0
        )
    }

    typealias RootViewType = YourValidatorListViewLayout

    let presenter: ParaStkYourCollatorsPresenterProtocol

    private var viewState: ParaStkYourCollatorsState?

    private var electedSize: Int {
        guard let viewModel = viewState?.viewModel else {
            return 0
        }

        let rewarded = viewModel.sections.first(where: { $0.status == .rewarded })?.collators.count ?? 0
        let notRewarded = viewModel.sections.first(where: { $0.status == .notRewarded })?.collators.count ?? 0

        return rewarded + notRewarded
    }

    private var rewardedSize: Int {
        guard let viewModel = viewState?.viewModel else {
            return 0
        }

        return viewModel.sections.first(where: { $0.status == .rewarded })?.collators.count ?? 0
    }

    let counterFormater: LocalizableResource<NumberFormatter>

    init(
        presenter: ParaStkYourCollatorsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        counterFormater: LocalizableResource<NumberFormatter> = NumberFormatter.quantity.localizableResource()
    ) {
        self.presenter = presenter
        self.counterFormater = counterFormater

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = YourValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.parachainStakingYourCollator(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable.stakingManageTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupNavigationItem() {
        let resetItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(actionManage)
        )

        resetItem.setupDefaultTitleStyle(with: UIFont.regularBody)

        navigationItem.rightBarButtonItem = resetItem
    }

    private func setupTableView() {
        rootView.tableView.registerClassesForCell([
            CollatorSelectionCell.self
        ])

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListDescSectionView.self
        )

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListStatusSectionView.self
        )

        rootView.tableView.registerHeaderFooterView(
            withClass: YourValidatorListWarningSectionView.self
        )

        rootView.tableView.rowHeight = 44

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    @objc func actionManage() {
        presenter.manageCollators()
    }
}

extension ParaStkYourCollatorsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewState?.viewModel?.sections.count ?? 0
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewState?.viewModel?.sections[section].collators.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CollatorSelectionCell.self)!

        guard let viewModel = viewState?.viewModel?.sections[indexPath.section].collators[indexPath.row] else {
            return cell
        }

        cell.bind(viewModel: viewModel, type: .accentOnSorting)
        cell.isInfoEnabled = false

        return cell
    }
}

extension ParaStkYourCollatorsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let viewModel = viewState?.viewModel?.sections[indexPath.section].collators[indexPath.row] else {
            return
        }

        presenter.selectCollator(viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let viewModel = viewState?.viewModel else {
            return nil
        }

        let sectionViewModel = viewModel.sections[section]

        var headerView: UIView?

        if section == 0, viewModel.hasCollatorWithoutRewards {
            let warningView: YourValidatorListWarningSectionView = tableView.dequeueReusableHeaderFooterView()
            headerView = warningView
        }

        switch sectionViewModel.status {
        case .rewarded:
            headerView = configureRewardedSection(for: headerView, tableView: tableView)
        case .notRewarded:
            headerView = configureNotRewardedSection(
                for: headerView,
                tableView: tableView,
                section: section
            )

        case .notElected:
            headerView = configureNotElectedSection(
                for: headerView,
                tableView: tableView,
                viewModel: sectionViewModel,
                section: section
            )
        case .pending:
            headerView = configurePendingSection(
                for: headerView,
                tableView: tableView,
                viewModel: sectionViewModel,
                section: section
            )
        }

        if let warningView = headerView as? YourValidatorListWarningSectionView {
            configureNoRewardsWarning(for: warningView)
        }

        return headerView
    }

    private func configureRewardedSection(for headerView: UIView?, tableView: UITableView) -> UIView? {
        let sectionView: YourValidatorListStatusSectionView = (headerView as? YourValidatorListStatusSectionView)
            ?? tableView.dequeueReusableHeaderFooterView()
        configureElected(headerView: sectionView, collatorsCount: electedSize)
        configureRewarded(headerView: sectionView)

        return sectionView
    }

    private func configureNotRewardedSection(
        for headerView: UIView?,
        tableView: UITableView,
        section: Int
    ) -> UIView? {
        if section == 0 {
            let sectionView: YourValidatorListStatusSectionView = (headerView as? YourValidatorListStatusSectionView)
                ?? tableView.dequeueReusableHeaderFooterView()
            configureElected(headerView: sectionView, collatorsCount: electedSize)
            configureNotRewarded(headerView: sectionView, section: section)

            return sectionView
        } else {
            let sectionView: YourValidatorListDescSectionView = tableView.dequeueReusableHeaderFooterView()
            configureNotRewarded(headerView: sectionView, section: section)

            return sectionView
        }
    }

    private func configureNotElectedSection(
        for headerView: UIView?,
        tableView: UITableView,
        viewModel: ParaStkYourCollatorListSection,
        section: Int
    ) -> UIView? {
        let sectionView: YourValidatorListStatusSectionView = (headerView as? YourValidatorListStatusSectionView)
            ?? tableView.dequeueReusableHeaderFooterView()

        configureNotElected(
            headerView: sectionView,
            collatorsCount: viewModel.collators.count,
            section: section
        )

        return sectionView
    }

    private func configurePendingSection(
        for headerView: UIView?,
        tableView: UITableView,
        viewModel: ParaStkYourCollatorListSection,
        section: Int
    ) -> UIView? {
        let sectionView: YourValidatorListStatusSectionView = (headerView as? YourValidatorListStatusSectionView)
            ?? tableView.dequeueReusableHeaderFooterView()

        configurePending(
            headerView: sectionView,
            collatorsCount: viewModel.collators.count,
            section: section
        )

        return sectionView
    }

    private func configureNoRewardsWarning(for headerView: YourValidatorListWarningSectionView) {
        let text = R.string.localizable.parastkYourCollatorsWarning(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(warningText: text)

        headerView.mainStackView.layoutMargins = Constants.warningHeaderMargins
    }

    private func configureElected(headerView: YourValidatorListStatusSectionView, collatorsCount: Int) {
        let icon = R.image.iconAlgoItem()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: collatorsCount)).map {
            R.string.localizable.stakingYourElectedFormat(
                $0,
                preferredLanguages: selectedLocale.rLanguages
            )
        } ?? ""

        headerView.statusView.detailsLabel.textColor = R.color.colorWhite()

        headerView.bind(icon: icon, title: title)

        headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
    }

    private func configureRewarded(headerView: YourValidatorListStatusSectionView) {
        let description = R.string.localizable.parastkYourRewardedDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(description: description)
    }

    private func configureNotRewarded(headerView: YourValidatorListDescSectionView, section: Int) {
        let description = R.string.localizable.parastkYourNotRewardedDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(description: description)

        if section > 0 {
            headerView.mainStackView.layoutMargins = Constants.notTopStatusHeaderMargins
        } else {
            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
        }
    }

    private func configureNotElected(
        headerView: YourValidatorListStatusSectionView,
        collatorsCount: Int,
        section: Int
    ) {
        let icon = R.image.iconPending()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: collatorsCount)).map {
            R.string.localizable.stakingYourNotElectedFormat(
                $0,
                preferredLanguages: selectedLocale.rLanguages
            )
        } ?? ""

        let description = R.string.localizable.parastkYourNotElectedDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.statusView.detailsLabel.textColor = R.color.colorTransparentText()

        headerView.bind(icon: icon, title: title)
        headerView.bind(description: description)

        if section > 0 {
            headerView.mainStackView.layoutMargins = Constants.notTopStatusHeaderMargins
        } else {
            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
        }
    }

    private func configurePending(
        headerView: YourValidatorListStatusSectionView,
        collatorsCount: Int,
        section: Int
    ) {
        let icon = R.image.iconPending()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: collatorsCount)).map {
            R.string.localizable.parastkYourPendingFormat(
                $0,
                preferredLanguages: selectedLocale.rLanguages
            )
        } ?? ""

        let description = R.string.localizable.parastkYourPendingDescription(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.statusView.detailsLabel.textColor = R.color.colorTransparentText()

        headerView.bind(icon: icon, title: title)
        headerView.bind(description: description)

        if section > 0 {
            headerView.mainStackView.layoutMargins = Constants.notTopStatusHeaderMargins
        } else {
            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
        }
    }

    private func updateChangeButtonState() {
        if case .loaded = viewState {
            navigationItem.rightBarButtonItem?.isEnabled = true
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }
}

extension ParaStkYourCollatorsViewController: ParaStkYourCollatorsViewProtocol {
    func reload(state: ParaStkYourCollatorsState) {
        viewState = state

        rootView.tableView.reloadData()
        reloadEmptyState(animated: true)
        updateChangeButtonState()
    }
}

extension ParaStkYourCollatorsViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.retry()
    }
}

extension ParaStkYourCollatorsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension ParaStkYourCollatorsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = viewState else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error
            errorView.delegate = self
            errorView.locale = selectedLocale
            return errorView
        case .loading:
            let loadingView = ListLoadingView()
            loadingView.titleLabel.text = R.string.localizable.commonLoadingCollators(
                preferredLanguages: selectedLocale.rLanguages
            )
            loadingView.start()
            return loadingView
        case .loaded:
            return nil
        }
    }
}

extension ParaStkYourCollatorsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error, .loading:
            return true
        case .loaded:
            return false
        }
    }
}

extension ParaStkYourCollatorsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
