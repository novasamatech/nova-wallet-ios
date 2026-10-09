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

    let priceWidget: SubtensorPriceWidgetView = .create { view in
        view.isHidden = true
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

    var periodControl: RoundedSegmentedControl { priceWidget.periodControl }

    var chartView: SubtensorSubnetPriceChartView { priceWidget.chartView }

    var chartUnavailableView: SubtensorChartUnavailableView { priceWidget.chartUnavailableView }

    func bind(viewModel: SubtensorPositionViewModel, locale: Locale) {
        summaryView.bind(viewModel: viewModel.summary, locale: locale)
        bind(priceWidget: viewModel.priceWidget)
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
    func bind(priceWidget viewModel: SubtensorPriceWidgetViewModel?) {
        priceWidget.isHidden = viewModel == nil

        if let viewModel {
            priceWidget.bind(viewModel: viewModel)
        }
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
            containerView.stackView.addArrangedSubview(priceWidget)
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

    func setupSyncNotice() {
        syncNoticeControl.addSubview(syncNoticeLabel)
        syncNoticeLabel.isUserInteractionEnabled = false
        syncNoticeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        containerView.stackView.addArrangedSubview(syncNoticeControl)
    }
}
