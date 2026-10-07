import UIKit
import UIKit_iOS

final class SubtensorPositionViewLayout: UIView {
    let isRoot: Bool

    let backgroundView = MultigradientView.background

    let containerView: ScrollableContainerView = .create { view in
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        view.stackView.alignment = .fill
        view.stackView.spacing = 16
    }

    let summaryView = SubtensorPositionSummaryView()

    let chartView = SubtensorSubnetPriceChartView(style: .price)

    let chartLoadingView = SubtensorChartLoadingView()

    let chartUnavailableView: SubtensorChartUnavailableView = .create { view in
        view.isHidden = true
    }

    let periodControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = .clear
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let actionsTableView: StackTableView = .create { view in
        view.hasSeparators = false
        view.contentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }

    let validatorView = SubtensorPositionValidatorView()

    let noticeView: SubtensorPositionNoticeView = .create { view in
        view.isHidden = true
    }

    let syncNoticeControl: UIControl = .create { view in
        view.backgroundColor = R.color.colorBlockBackground()
        view.layer.cornerRadius = 12
        view.isHidden = true
    }

    let syncNoticeLabel: UILabel = .create { label in
        label.apply(style: .footnotePrimary)
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    let sellButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    let buyButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    var onSelectAction: ((SubtensorPositionAction) -> Void)?

    private let chartContainer = UIView()
    private var actionCells: [StackActionCell] = []
    private var actions: [SubtensorPositionAction] = []

    init(isRoot: Bool) {
        self.isRoot = isRoot

        super.init(frame: .zero)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPositionViewModel, locale: Locale) {
        summaryView.bind(viewModel: viewModel.summary, locale: locale)
        bind(chart: viewModel.chart)
        bind(actions: viewModel.actions)
        validatorView.bind(viewModel: viewModel.validator)

        noticeView.isHidden = viewModel.notice == nil

        if let notice = viewModel.notice {
            noticeView.bind(viewModel: notice)
        }

        syncNoticeControl.isHidden = !viewModel.isSyncFailed
        syncNoticeLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorUiPortfolioSyncFailed()
    }
}

private extension SubtensorPositionViewLayout {
    enum Constants {
        static let chartHeight: CGFloat = 208
        static let controlHeight: CGFloat = 32
    }

    func bind(chart viewModel: SubtensorPositionChartViewModel?) {
        guard let viewModel else {
            chartContainer.isHidden = true
            periodControl.isHidden = true
            chartLoadingView.setLoading(false)
            return
        }

        chartContainer.isHidden = false
        periodControl.isHidden = false
        chartLoadingView.setLoading(viewModel.chart == .loading)

        switch viewModel.chart {
        case .loading:
            chartView.isHidden = true
            chartUnavailableView.isHidden = true
        case let .chart(chartViewModel):
            chartView.isHidden = false
            chartUnavailableView.isHidden = true
            chartView.bind(viewModel: chartViewModel)
        case let .unavailable(title, details):
            chartView.isHidden = true
            chartUnavailableView.isHidden = false
            chartUnavailableView.bind(title: title, details: details, isAction: false)
        case let .failed(title, action):
            chartView.isHidden = true
            chartUnavailableView.isHidden = false
            chartUnavailableView.bind(title: title, details: action, isAction: true)
        }

        if periodControl.titles != viewModel.periods.titles {
            periodControl.titles = viewModel.periods.titles
        }

        periodControl.selectedSegmentIndex = viewModel.periods.selectedIndex
        periodControl.isEnabled = viewModel.periods.isEnabled
        periodControl.alpha = viewModel.periods.isEnabled ? 1 : 0.4
    }

    func bind(actions viewModels: [SubtensorPositionActionViewModel]) {
        actions = viewModels.map(\.action)

        for viewModel in viewModels {
            switch viewModel.action {
            case .claim, .addStake, .unstake:
                bindCell(for: viewModel)
            case .sell:
                bind(button: sellButton, viewModel: viewModel, isPrimary: false)
            case .buy:
                bind(button: buyButton, viewModel: viewModel, isPrimary: true)
            }
        }
    }

    func bindCell(for viewModel: SubtensorPositionActionViewModel) {
        guard let index = actions.firstIndex(of: viewModel.action), index < actionCells.count else {
            return
        }

        let icon = switch viewModel.action {
        case .claim:
            R.image.iconPendingRewards()
        case .addStake:
            R.image.iconBondMore()
        case .unstake, .buy, .sell:
            R.image.iconUnbond()
        }

        let cell = actionCells[index]

        cell.bind(title: viewModel.title, icon: icon, details: viewModel.details)
        cell.isUserInteractionEnabled = viewModel.isEnabled
        cell.rowContentView.alpha = viewModel.isEnabled ? 1 : 0.4
    }

    func bind(button: TriangularedButton, viewModel: SubtensorPositionActionViewModel, isPrimary: Bool) {
        if !viewModel.isEnabled {
            button.applyDisabledStyle()
        } else if isPrimary {
            button.applyDefaultStyle()
        } else {
            button.applySecondaryDefaultStyle()
        }

        button.isUserInteractionEnabled = viewModel.isEnabled
        button.imageWithTitleView?.title = viewModel.title
        button.invalidateLayout()
    }

    @objc func actionCell(_ sender: UIControl) {
        guard
            let cell = sender as? StackActionCell,
            let index = actionCells.firstIndex(of: cell),
            index < actions.count else {
            return
        }

        onSelectAction?(actions[index])
    }

    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        if isRoot {
            addSubview(containerView)
            containerView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            setupBottomBar()
        }

        containerView.stackView.addArrangedSubview(summaryView)

        if isRoot {
            setupActions()
            containerView.stackView.addArrangedSubview(validatorView)
            containerView.stackView.addArrangedSubview(noticeView)
        } else {
            setupChart()
            containerView.stackView.addArrangedSubview(noticeView)
            containerView.stackView.addArrangedSubview(validatorView)
        }

        setupSyncNotice()
    }

    func setupBottomBar() {
        let buttonsView = UIView.hStack(distribution: .fillEqually, spacing: 16, [sellButton, buyButton])

        addSubview(buttonsView)
        buttonsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(buttonsView.snp.top).offset(-16)
        }
    }

    func setupActions() {
        let backgroundView: UIView = .create { view in
            view.backgroundColor = R.color.colorBlockBackground()
            view.layer.cornerRadius = 12
        }

        backgroundView.addSubview(actionsTableView)
        actionsTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        actionCells = (0 ..< 3).map { _ in
            let cell = StackActionCell()
            cell.rowContentView.disclosureIndicatorView.image = R.image.iconSmallArrow()?
                .tinted(with: R.color.colorIconSecondary()!)
            cell.addTarget(self, action: #selector(actionCell(_:)), for: .touchUpInside)
            actionsTableView.addArrangedSubview(cell)
            return cell
        }

        containerView.stackView.addArrangedSubview(backgroundView)
    }

    func setupChart() {
        [chartView, chartLoadingView, chartUnavailableView].forEach { view in
            chartContainer.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        chartContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.chartHeight)
        }

        chartContainer.isHidden = true
        periodControl.isHidden = true

        containerView.stackView.addArrangedSubview(chartContainer)
        containerView.stackView.addArrangedSubview(periodControl)

        periodControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.controlHeight)
        }
    }

    func setupSyncNotice() {
        syncNoticeControl.addSubview(syncNoticeLabel)
        syncNoticeLabel.isUserInteractionEnabled = false
        syncNoticeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        containerView.stackView.addArrangedSubview(syncNoticeControl)
    }
}
