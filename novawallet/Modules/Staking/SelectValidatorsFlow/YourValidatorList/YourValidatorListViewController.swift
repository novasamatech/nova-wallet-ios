import UIKit
import Foundation_iOS
import UIKit_iOS

final class YourValidatorListViewController: UIViewController, ViewHolder {
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

    let presenter: YourValidatorListPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private var viewState: YourValidatorListViewState?

    let counterFormater: LocalizableResource<NumberFormatter>

    init(
        presenter: YourValidatorListPresenterProtocol,
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

    // MARK: Lifecycle -

    override func loadView() {
        view = YourValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupLocalization()
        updateChangeButtonState()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: selectedLocale.rLanguages)

        navigationItem.rightBarButtonItem?.title = R.string.localizable
            .commonChange(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupNavigationItem() {
        let resetItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(actionChange)
        )

        resetItem.setupDefaultTitleStyle(with: UIFont.regularBody)

        navigationItem.rightBarButtonItem = resetItem
    }

    private func setupTableView() {
        rootView.tableView.registerClassesForCell([
            YourValidatorTableCell.self
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

    @objc func actionChange() {
        presenter.changeValidators()
    }
}

// MARK: - UITableViewDataSource

extension YourValidatorListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard case let .validatorList(viewModel) = viewState else {
            return 0
        }

        return viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .validatorList(viewModel) = viewState else {
            return 0
        }

        return viewModel.sections[section].validators.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(YourValidatorTableCell.self)!

        guard case let .validatorList(viewModel) = viewState else {
            return cell
        }

        let section = viewModel.sections[indexPath.section]
        let validator = section.validators[indexPath.row]

        cell.bind(viewModel: validator, for: selectedLocale)

        return cell
    }
}

// MARK: UITableViewDelegate

extension YourValidatorListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .validatorList(viewModel) = viewState else {
            return
        }

        let section = viewModel.sections[indexPath.section]

        presenter.didSelectValidator(viewModel: section.validators[indexPath.row])
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .validatorList(viewModel) = viewState else {
            return nil
        }

        let sectionViewModel = viewModel.sections[section]

        switch sectionViewModel.status {
        case .stakeAllocated:
            let count = viewModel.sections.first(where: { $0.status == .stakeNotAllocated }).map {
                $0.validators.count + sectionViewModel.validators.count
            } ?? sectionViewModel.validators.count

            if viewModel.allValidatorWithoutRewards {
                let headerView: YourValidatorListWarningSectionView = tableView.dequeueReusableHeaderFooterView()
                configureWarning(headerView: headerView, validatorsCount: count)
                return headerView
            } else {
                let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
                configureElected(headerView: headerView, validatorsCount: count)
                return headerView
            }
        case .stakeNotAllocated:
            let headerView: YourValidatorListDescSectionView = tableView.dequeueReusableHeaderFooterView()
            configureNotAllocated(headerView: headerView, section: section)

            return headerView
        case .unelected:
            let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            configureUnelected(
                headerView: headerView,
                validatorsCount: sectionViewModel.validators.count,
                section: section
            )

            return headerView
        case .pending:
            let headerView: YourValidatorListStatusSectionView = tableView.dequeueReusableHeaderFooterView()
            configurePending(
                headerView: headerView,
                validatorsCount: sectionViewModel.validators.count,
                section: section
            )

            return headerView
        }
    }

    private func configureWarning(headerView: YourValidatorListWarningSectionView, validatorsCount: Int) {
        configureElected(headerView: headerView, validatorsCount: validatorsCount)

        let text = R.string.localizable.stakingYourOversubscribedMessage(
            preferredLanguages: selectedLocale.rLanguages
        )

        headerView.bind(warningText: text)

        headerView.mainStackView.layoutMargins = Constants.warningHeaderMargins
    }

    private func configureElected(headerView: YourValidatorListStatusSectionView, validatorsCount: Int) {
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

        headerView.statusView.detailsLabel.textColor = R.color.colorTextPrimary()

        headerView.bind(icon: icon, title: title)
        headerView.bind(description: description)

        headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
    }

    private func configureNotAllocated(headerView: YourValidatorListDescSectionView, section: Int) {
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

    private func configureUnelected(
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

        headerView.statusView.detailsLabel.textColor = R.color.colorTextSecondary()

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

        headerView.statusView.detailsLabel.textColor = R.color.colorTextSecondary()

        headerView.bind(icon: icon, title: title)
        headerView.bind(description: description)

        if section > 0 {
            headerView.mainStackView.layoutMargins = Constants.notTopStatusHeaderMargins
        } else {
            headerView.mainStackView.layoutMargins = Constants.regularHeaderMargins
        }
    }

    private func updateChangeButtonState() {
        if case .validatorList = viewState {
            navigationItem.rightBarButtonItem?.isEnabled = true
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }
}

extension YourValidatorListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.retry()
    }
}

extension YourValidatorListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension YourValidatorListViewController: EmptyStateDataSource {
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
            loadingView.titleLabel.text = R.string.localizable.stakingLoadingValidators(
                preferredLanguages: selectedLocale.rLanguages
            )
            loadingView.start()
            return loadingView
        case .validatorList:
            return nil
        }
    }
}

extension YourValidatorListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error, .loading:
            return true
        case .validatorList:
            return false
        }
    }
}

extension YourValidatorListViewController: YourValidatorListViewProtocol {
    func reload(state: YourValidatorListViewState) {
        viewState = state

        rootView.tableView.reloadData()
        reloadEmptyState(animated: true)
        updateChangeButtonState()
    }
}

extension YourValidatorListViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
