import UIKit
import SubstrateSdk
import Foundation_iOS
import BigInt

/// Modal view controller that displays a searchable list of Bittensor
/// validators. The caller passes a netuid, an optional pre-fetched validator
/// list, and an `onSelection` callback. v1 only ever passes
/// `SubtensorStakingConstants.rootNetuid`, but the parameter is plumbed
/// through so subnet variants compose without rewrites.
///
/// The picker is intentionally self-contained: it does its own data
/// fetching via `SubtensorValidatorProvider` rather than going through a
/// VIPER interactor/presenter for v1. The closure-based selection keeps
/// integration with the setup screen trivial. If a follow-up needs more
/// state (real APR, sort modes, hand-off to confirm flow), this can be
/// upgraded to a full VIPER module without any caller-side changes.
final class SubtensorValidatorPickerViewController: UIViewController {
    typealias RootViewType = SubtensorValidatorPickerViewLayout

    private let netuid: UInt16
    private let validatorProvider: SubtensorValidatorProvider
    private let onSelection: (SubtensorValidator) -> Void
    private let cellViewModelFactory: SubtensorValidatorCellViewModelFactory

    private var allValidators: [SubtensorValidator] = []
    private var filteredViewModels: [SubtensorValidatorCellViewModel] = []
    private var fetchTask: Task<Void, Never>?
    private var filterState: SubtensorValidatorFilterViewController.State = .default

    init(
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid,
        validatorProvider: SubtensorValidatorProvider,
        cellViewModelFactory: SubtensorValidatorCellViewModelFactory,
        prefetched: [SubtensorValidator]? = nil,
        onSelection: @escaping (SubtensorValidator) -> Void
    ) {
        self.netuid = netuid
        self.validatorProvider = validatorProvider
        self.cellViewModelFactory = cellViewModelFactory
        self.onSelection = onSelection

        super.init(nibName: nil, bundle: nil)

        if let prefetched, !prefetched.isEmpty {
            allValidators = prefetched
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        fetchTask?.cancel()
    }

    var rootView: RootViewType {
        // swiftlint:disable:next force_cast
        view as! RootViewType
    }

    override func loadView() {
        view = SubtensorValidatorPickerViewLayout()
    }

    private lazy var searchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconSearchWhite(), for: .normal)
        return button
    }()

    private lazy var filterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFilter(), for: .normal)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO(phase-e): R.string.localizable.stakingSubtensorPickerTitle(...)
        title = "Select validator"
        navigationItem.largeTitleDisplayMode = .always

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.register(
            SubtensorValidatorTableViewCell.self,
            forCellReuseIdentifier: SubtensorValidatorTableViewCell.reuseId
        )
        rootView.retryButton.addTarget(self, action: #selector(actionRetry), for: .touchUpInside)

        setupNavigationBar()

        if !allValidators.isEmpty {
            applyValidators(allValidators)
        } else {
            loadValidators()
        }
    }

    private func setupNavigationBar() {
        // Order matters: rightBarButtonItems renders right-to-left, so passing
        // [filter, search] places filter as the rightmost icon (matches the
        // Polkadot custom-validators screen).
        let filterBarButton = UIBarButtonItem(customView: filterButton)
        let searchBarButton = UIBarButtonItem(customView: searchButton)
        navigationItem.rightBarButtonItems = [filterBarButton, searchBarButton]

        searchButton.addTarget(self, action: #selector(tapSearchButton), for: .touchUpInside)
        filterButton.addTarget(self, action: #selector(tapFilterButton), for: .touchUpInside)
    }

    @objc private func tapSearchButton() {
        let search = SubtensorValidatorSearchViewController(
            prefetched: allValidators,
            netuid: netuid,
            cellViewModelFactory: cellViewModelFactory,
            onSelection: { [weak self] validator in
                guard let self else { return }
                self.dismiss(animated: true) {
                    self.onSelection(validator)
                    self.navigationController?.popViewController(animated: true)
                }
            }
        )
        // Provide a back-arrow style left bar button to match Polkadot's
        // search modal — drag-to-dismiss alone can be unintuitive.
        search.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: search,
            action: #selector(SubtensorValidatorSearchViewController.dismissAnimated)
        )

        let nav = UINavigationController(rootViewController: search)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func tapFilterButton() {
        let filter = SubtensorValidatorFilterViewController(
            state: filterState,
            onApply: { [weak self] newState in
                guard let self else { return }
                self.filterState = newState
                self.refreshFilterButtonStyle()
                self.applyValidators(self.allValidators)
            }
        )
        filter.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: filter,
            action: #selector(SubtensorValidatorFilterViewController.dismissAnimated)
        )

        let nav = UINavigationController(rootViewController: filter)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func refreshFilterButtonStyle() {
        let active = filterState != .default
        filterButton.setImage(
            active ? R.image.iconFilterActive() : R.image.iconFilter(),
            for: .normal
        )
    }

    @objc private func actionRetry() {
        loadValidators()
    }

    private func loadValidators() {
        rootView.showState(.loading)
        fetchTask?.cancel()

        let provider = validatorProvider
        let captureNetuid = netuid

        fetchTask = Task { @MainActor [weak self] in
            do {
                let result = try await provider.fetchValidators(netuid: captureNetuid)
                guard !Task.isCancelled, let self else { return }
                self.allValidators = result
                self.applyValidators(result)
            } catch {
                guard !Task.isCancelled, let self else { return }
                Logger.shared.error("SubtensorValidatorPicker fetch failed: \(error.localizedDescription)")
                self.rootView.showState(.error)
            }
        }
    }

    private func applyValidators(_ validators: [SubtensorValidator]) {
        if validators.isEmpty {
            filteredViewModels = []
            rootView.showState(.empty)
            return
        }

        let filtered = validators.filter { validator in
            if filterState.requireIdentity, (validator.identity ?? "").isEmpty {
                return false
            }
            if filterState.hideMaxCommission, validator.commission >= 1.0 {
                return false
            }
            return true
        }

        let sorted: [SubtensorValidator]
        switch filterState.sort {
        case .totalStakeDesc:
            sorted = filtered.sorted { $0.totalStake > $1.totalStake }
        case .aprDesc:
            // Validators without APR data sink to the bottom (TaoStats only
            // returns APR for the validators present in its top-stake sample).
            sorted = filtered.sorted { ($0.apr ?? -1) > ($1.apr ?? -1) }
        }

        filteredViewModels = sorted.map { cellViewModelFactory.create(from: $0, netuid: netuid) }
        rootView.tableView.reloadData()
        rootView.showState(filteredViewModels.isEmpty ? .empty : .loaded)
    }
}

// MARK: - UITableViewDataSource

extension SubtensorValidatorPickerViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        filteredViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorValidatorTableViewCell.reuseId,
            for: indexPath
        ) as? SubtensorValidatorTableViewCell ?? SubtensorValidatorTableViewCell(
            style: .default,
            reuseIdentifier: SubtensorValidatorTableViewCell.reuseId
        )

        cell.bind(viewModel: filteredViewModels[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SubtensorValidatorPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let viewModel = filteredViewModels[indexPath.row]
        guard let validator = allValidators.first(where: { $0.hotkey == viewModel.hotkey }) else {
            return
        }
        onSelection(validator)
        navigationController?.popViewController(animated: true)
    }
}
