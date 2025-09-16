import UIKit
import Foundation_iOS

final class SwipeGovVotingListViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwipeGovVotingListViewLayout

    let presenter: SwipeGovVotingListPresenterProtocol

    private var viewModel: SwipeGovVotingListViewModel?

    init(
        presenter: SwipeGovVotingListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovVotingListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupNavigationBar()
        setupVoteButton()

        setupLocalizables()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.becomeActive()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.becomeInactive()
    }
}

// MARK: SwipeGovVotingListViewProtocol

extension SwipeGovVotingListViewController: SwipeGovVotingListViewProtocol {
    func didReceive(_ viewModel: SwipeGovVotingListViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }
}

// MARK: UITableViewDataSource

extension SwipeGovVotingListViewController: UITableViewDataSource {
    func tableView(
        _: UITableView,
        numberOfRowsInSection _: Int
    ) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(SwipeGovVotingListItemCell.self)!

        let cellViewModel = viewModel.cellViewModels[indexPath.row]
        cell.bind(viewModel: cellViewModel)

        return cell
    }

    func tableView(
        _: UITableView,
        commit _: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard let cellModel = viewModel?.cellViewModels[indexPath.row] else {
            return
        }

        presenter.removeItem(with: cellModel.referendumIndex)
    }
}

// MARK: - UITableViewDelegate

extension SwipeGovVotingListViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let cellModel = viewModel?.cellViewModels[indexPath.row] else {
            return
        }

        presenter.selectVoting(for: cellModel.referendumIndex)
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        44
    }
}

// MARK: Localizable

extension SwipeGovVotingListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            updateEditButton()
        }
    }
}

// MARK: Private

private extension SwipeGovVotingListViewController {
    func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SwipeGovVotingListItemCell.self)
    }

    func setupNavigationBar() {
        let rightBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(tapEditButton)
        )

        rightBarButtonItem.setupDefaultTitleStyle(with: .regularBody)

        navigationItem.rightBarButtonItem = rightBarButtonItem

        updateEditButton()
    }

    func setupVoteButton() {
        rootView.voteButton.addTarget(
            self,
            action: #selector(tapVoteButton),
            for: .touchUpInside
        )
        updateVoteButton()
    }

    func updateEditButton() {
        if rootView.tableView.isEditing {
            navigationItem.rightBarButtonItem?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonDone()
        } else {
            navigationItem.rightBarButtonItem?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonEdit()
        }
    }

    func updateVoteButton() {
        if !rootView.tableView.isEditing {
            rootView.voteButton.isUserInteractionEnabled = true
            rootView.voteButton.applyEnabledStyle()
        } else {
            rootView.voteButton.isUserInteractionEnabled = false
            rootView.voteButton.applyDisabledStyle()
        }
    }

    func setupLocalizables() {
        navigationItem.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govVotingListTitle()
        rootView.voteButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.govVote()
    }
}

// MARK: Handlers

private extension SwipeGovVotingListViewController {
    @objc func tapEditButton() {
        rootView.tableView.setEditing(
            !rootView.tableView.isEditing,
            animated: true
        )
        updateEditButton()
        updateVoteButton()
    }

    @objc func tapVoteButton() {
        presenter.vote()
    }
}
