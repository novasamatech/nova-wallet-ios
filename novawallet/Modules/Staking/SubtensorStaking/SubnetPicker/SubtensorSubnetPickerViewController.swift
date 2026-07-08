import UIKit
import Foundation_iOS
import SubstrateSdk

/// Displays a scrollable list of Bittensor subnets. Each row shows
/// the subnet name, netuid, TAO reserve, and spot price (TAO per alpha).
/// The user taps a row → the callback fires with the selected netuid.
///
/// Data is fetched via direct RPC calls to the chain — no indexer needed.
/// Uses `ChainRegistryFacade` for the WebSocket connection.
final class SubtensorSubnetPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let chainAsset: ChainAsset
    private let onSelection: (SubtensorSubnetInfo) -> Void

    private var allSubnets: [SubtensorSubnetInfo] = []
    private var subnets: [SubtensorSubnetInfo] = []
    private var isLoading = true
    private var filterState: SubtensorSubnetFilterViewController.State = .default

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

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = R.color.colorSecondaryScreenBackground()
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 72
        tv.register(SubtensorSubnetCell.self, forCellReuseIdentifier: SubtensorSubnetCell.reuseId)
        return tv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    init(
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        onSelection: @escaping (SubtensorSubnetInfo) -> Void
    ) {
        self.chainAsset = chainAsset
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = R.string(preferredLanguages: selectedLocale.rLanguages)
            .localizable.stakingSubtensorSubnetPickerTitle()

        view.backgroundColor = R.color.colorSecondaryScreenBackground()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { $0.center.equalToSuperview() }

        tableView.dataSource = self
        tableView.delegate = self

        setupNavigationBar()

        fetchSubnets()
    }

    private func setupNavigationBar() {
        let filterBarButton = UIBarButtonItem(customView: filterButton)
        let searchBarButton = UIBarButtonItem(customView: searchButton)
        navigationItem.rightBarButtonItems = [filterBarButton, searchBarButton]
        searchButton.addTarget(self, action: #selector(tapSearchButton), for: .touchUpInside)
        filterButton.addTarget(self, action: #selector(tapFilterButton), for: .touchUpInside)
    }

    @objc private func tapSearchButton() {
        let search = SubtensorSubnetSearchViewController(
            allSubnets: allSubnets,
            onSelection: { [weak self] subnet in
                guard let self else { return }
                self.dismiss(animated: true) {
                    self.onSelection(subnet)
                }
            }
        )
        search.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: search,
            action: #selector(SubtensorSubnetSearchViewController.dismissAnimated)
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
        let filter = SubtensorSubnetFilterViewController(
            state: filterState,
            onApply: { [weak self] newState in
                guard let self else { return }
                self.filterState = newState
                self.refreshFilterButtonStyle()
                self.applySort()
            }
        )
        filter.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: filter,
            action: #selector(SubtensorSubnetFilterViewController.dismissAnimated)
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

    private func applySort() {
        switch filterState.sort {
        case .totalStakeDesc:
            subnets = allSubnets.sorted { $0.taoReserve > $1.taoReserve }
        case .netuidAsc:
            subnets = allSubnets.sorted { $0.netuid < $1.netuid }
        }
        tableView.reloadData()
    }

    // MARK: - Data fetching

    private func fetchSubnets() {
        activityIndicator.startAnimating()

        Task { @MainActor in
            do {
                let fetched = try await SubtensorSubnetFetcher.fetchAllSubnets(
                    chainId: chainAsset.chain.chainId
                )
                self.allSubnets = fetched
                self.applySort()
                self.isLoading = false
                self.activityIndicator.stopAnimating()
            } catch {
                self.isLoading = false
                self.activityIndicator.stopAnimating()
                Logger.shared.error("SubnetPicker: failed to fetch subnets — \(error)")
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        subnets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubtensorSubnetCell.reuseId,
            for: indexPath
        ) as? SubtensorSubnetCell else {
            return UITableViewCell()
        }

        let subnet = subnets[indexPath.row]
        cell.bind(subnet: subnet)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subnet = subnets[indexPath.row]
        onSelection(subnet)
    }
}

// MARK: - Localizable

extension SubtensorSubnetPickerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string(preferredLanguages: selectedLocale.rLanguages)
                .localizable.stakingSubtensorSubnetPickerTitle()
        }
    }
}
