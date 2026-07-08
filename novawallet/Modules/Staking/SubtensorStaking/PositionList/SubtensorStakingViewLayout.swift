import UIKit
import UIKit_iOS
import SnapKit

/// Layout for the TAO staking dashboard screen.
/// Three states: loading, empty (no positions on the entry netuid), loaded.
/// Mirrors the Avail/AZERO main staking screen pattern.
final class SubtensorStakingViewLayout: UIView {
    // MARK: - Loading state

    let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = R.color.colorIconSecondary()
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Empty state

    let emptyContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()

    let emptyTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "No active stakes"
        label.font = .boldTitle3
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .center
        return label
    }()

    let emptySubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose a validator and delegate TAO to start earning rewards."
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let startStakingButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.imageWithTitleView?.title = "Start Staking"
        return button
    }()

    // MARK: - Background

    let backgroundGradientView = MultigradientView.background

    // MARK: - Loaded state

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        view.stackView.distribution = .fill
        view.stackView.spacing = 12.0
        view.isHidden = true
        return view
    }()

    let stakeCardView = SubtensorStakeAmountsView()

    let actionsTable: StackTableView = {
        let view = StackTableView()
        view.cornerRadius = 12.0
        view.hasSeparators = true
        view.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)
        return view
    }()

    let stakeMoreCell: StackActionCell = makeActionCell()
    let unstakeCell: StackActionCell = makeActionCell()

    let validatorListView = SubtensorValidatorListView()
    let stakingInfoView = SubtensorStakingInfoView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    // MARK: - Layout

    private func setupLayout() {
        addSubview(backgroundGradientView)
        backgroundGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Stake card — single aggregated total for the entry netuid.
        let stakeCardWrap = UIView()
        stakeCardWrap.addSubview(stakeCardView)
        stakeCardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        // Action list — Stake more / Unstake. "Your positions" is gone;
        // per-validator detail now lives inline in the validators card
        // below, so there is nothing to drill into.
        let actionsWrap = UIView()
        actionsWrap.addSubview(actionsTable)
        actionsTable.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        actionsTable.addArrangedSubview(stakeMoreCell)
        actionsTable.addArrangedSubview(unstakeCell)

        let validatorWrap = UIView()
        validatorWrap.addSubview(validatorListView)
        validatorListView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let infoWrap = UIView()
        infoWrap.addSubview(stakingInfoView)
        stakingInfoView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        // Order per UX: stake total → action list → validator detail → info.
        containerView.stackView.addArrangedSubview(stakeCardWrap)
        containerView.stackView.addArrangedSubview(actionsWrap)
        containerView.stackView.addArrangedSubview(validatorWrap)
        containerView.stackView.addArrangedSubview(infoWrap)

        emptyContainer.addArrangedSubview(emptyTitleLabel)
        emptyContainer.addArrangedSubview(emptySubtitleLabel)
        emptyContainer.addArrangedSubview(startStakingButton)

        startStakingButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            startStakingButton.widthAnchor.constraint(equalToConstant: 220),
            startStakingButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        addSubview(emptyContainer)
        emptyContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            emptyContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            emptyContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    // MARK: - State

    func showState(_ state: ScreenState) {
        switch state {
        case .loading:
            loadingIndicator.startAnimating()
            containerView.isHidden = true
            emptyContainer.isHidden = true
        case .empty:
            loadingIndicator.stopAnimating()
            containerView.isHidden = true
            emptyContainer.isHidden = false
        case .loaded:
            loadingIndicator.stopAnimating()
            containerView.isHidden = false
            emptyContainer.isHidden = true
        }
    }

    // MARK: - Helpers

    private static func makeActionCell() -> StackActionCell {
        let cell = StackActionCell()
        cell.rowContentView.disclosureIndicatorView.image = R.image.iconSmallArrow()?
            .tinted(with: R.color.colorIconSecondary()!)
        cell.rowContentView.detailsView.titleLabel.textColor = R.color.colorTextSecondary()
        return cell
    }
}

extension SubtensorStakingViewLayout {
    enum ScreenState {
        case loading
        case empty
        case loaded
    }
}
