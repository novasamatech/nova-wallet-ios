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

        switch sectionViewModel.status {
        case .rewarded:
            let count = viewModel.sections.first(where: { $0.status == .notRewarded }).map {
                $0.collators.count + sectionViewModel.collators.count
            } ?? sectionViewModel.collators.count

            if viewModel.hasCollatorWithoutRewards {
                let headerView: YourValidatorListWarningSectionView = tableView.dequeueReusableHeaderFooterView()
                configureWarning(headerView: headerView, validatorsCount: count)
                return headerView
            } else {
                let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
                configureRewarded(headerView: headerView, validatorsCount: count)
                return headerView
            }
        case .notRewarded:
            let headerView: YourValidatorListDescSectionView = tableView.dequeueReusableHeaderFooterView()
            configureNotRewarded(headerView: headerView, section: section)

            return headerView
        case .notElected:
            let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            configureNotElected(
                headerView: headerView,
                validatorsCount: sectionViewModel.collators.count,
                section: section
            )

            return headerView
        case .pending:
            let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            configurePending(
                headerView: headerView,
                validatorsCount: sectionViewModel.collators.count,
                section: section
            )

            return headerView
        }
    }

    private func configureWarning(headerView: YourValidatorListWarningSectionView, validatorsCount: Int) {
        configureRewarded(headerView: headerView, validatorsCount: validatorsCount)

        let text = R.string.localizable.stakingYourOversubscribedMessage(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(warningText: text)

        headerView.mainStackView.layoutMargins = Constants.warningHeaderMargins
    }

    private func configureRewarded(headerView: YourValidatorListStatusSectionView, validatorsCount: Int) {
        let icon = R.image.iconAlgoItem()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: validatorsCount)).map {
            R.string.localizable.stakingYourElectedFormat(
                $0,
                preferredLanguages: selectedLocale.rLanguages
            )
        } ?? ""

        let description = R.string.localizable.stakingYourAllocatedDescription_2_2_0(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.statusView.detailsLabel.textColor = R.color.colorWhite()

        headerView.bind(icon: icon, title: title)
        headerView.bind(description: description)

        headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
    }

    private func configureNotRewarded(headerView: YourValidatorListDescSectionView, section: Int) {
        let description = R.string.localizable.stakingYourNotAllocatedDescription_v2_2_0(
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
        validatorsCount: Int,
        section: Int
    ) {
        let icon = R.image.iconPending()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: validatorsCount)).map {
            R.string.localizable.stakingYourNotElectedFormat(
                $0,
                preferredLanguages: selectedLocale.rLanguages
            )
        } ?? ""

        let description = R.string.localizable.stakingYourInactiveDescription_v2_2_0(
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
        validatorsCount: Int,
        section: Int
    ) {
        let icon = R.image.iconPending()!
        let title = counterFormater.value(for: selectedLocale).string(from: NSNumber(value: validatorsCount)).map {
            R.string.localizable.stakingYourSelectedFormat(
                $0,
                preferredLanguages: selectedLocale.rLanguages
            )
        } ?? ""

        let description = R.string.localizable.stakingYourValidatorsChangingTitle(
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
