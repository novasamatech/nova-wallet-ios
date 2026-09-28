import Foundation_iOS
import UIKit

final class SubtensorPositionViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorPositionViewLayout

    let presenter: SubtensorPositionPresenterProtocol

    init(
        presenter: SubtensorPositionPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = SubtensorPositionViewLayout() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        rootView.addStakeButton.addTarget(self, action: #selector(actionBuy), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(actionBuy), for: .touchUpInside)
        rootView.unstakeButton.addTarget(self, action: #selector(actionSell), for: .touchUpInside)
        rootView.sellButton.addTarget(self, action: #selector(actionSell), for: .touchUpInside)
        rootView.validatorCard.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(actionValidatorInfo)
        ))
        rootView.periodButtons[1].backgroundColor = R.color.colorContainerBackground()
        for (index, button) in rootView.periodButtons.enumerated() {
            button.tag = index
            button.addTarget(self, action: #selector(actionPeriod(_:)), for: .touchUpInside)
        }
        presenter.setup()
    }

    @objc private func actionBuy() { presenter.stakeMore() }
    @objc private func actionSell() { presenter.unstake() }
    @objc private func actionValidatorInfo() { presenter.showValidatorInfo() }
    @objc private func actionPeriod(_ sender: UIButton) {
        let periods: [SubtensorPricePeriod] = [.day, .week, .month, .quarter, .year]
        rootView.periodButtons.forEach { $0.backgroundColor = .clear }
        sender.backgroundColor = R.color.colorContainerBackground()
        presenter.selectPeriod(periods[sender.tag])
    }

    private func setupLocalization() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        rootView.validatorCaption.text = strings.stakingSubtensorUiPositionValidator()
        rootView.addStakeButton.setTitle("＋  \(strings.stakingSubtensorUiPositionAddStake())  ›", for: .normal)
        rootView.unstakeButton.setTitle("－  \(strings.stakingSubtensorUiPositionUnstake())  ›", for: .normal)
        rootView.sellButton.setTitle(strings.stakingSubtensorUiPositionSell(), for: .normal)
        rootView.buyButton.imageWithTitleView?.title = strings.stakingSubtensorUiPositionBuy()
        rootView.buyButton.invalidateLayout()
    }
}

extension SubtensorPositionViewController: SubtensorPositionViewProtocol {
    func didReceive(viewModel: SubtensorPositionViewModel) {
        title = viewModel.title
        rootView.setRootMode(viewModel.isRoot)
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        rootView.captionLabel.text = viewModel.isRoot
            ? strings.stakingSubtensorUiPositionStakedRoot() : viewModel.title
        rootView.amountLabel.text = viewModel.amount
        let currency = CurrencyManager.shared?.selectedCurrency
        rootView.fiatLabel.text = viewModel.fiat.map {
            "≈ \(currency?.symbol ?? currency?.code ?? "")\($0)"
        }
        rootView.statusLabel.text = "● \(strings.stakingSubtensorUiPositionActive())"
        rootView.rewardTitleLabel.text = viewModel.rewardTitle
        rootView.rewardValueLabel.text = viewModel.rewardValue ?? strings.stakingSubtensorUiPositionCompounds()
        rootView.worthTitleLabel.text = strings.stakingSubtensorUiPositionWorth()
        rootView.worthValueLabel.text = viewModel.worthNow
        rootView.validatorLabel.text = viewModel.validator
        rootView.holdNoticeLabel.text = strings.stakingSubtensorUiPositionHoldNotice()
        rootView.holdNoticeCard.isHidden = !viewModel.hasRootHold
        rootView.addStakeButton.isEnabled = viewModel.canOperate
        rootView.unstakeButton.isEnabled = viewModel.canOperate
        rootView.buyButton.isEnabled = viewModel.canOperate
        rootView.sellButton.isEnabled = viewModel.canOperate
    }

    func didReceive(history: SubtensorPriceHistoryResult?) {
        switch history {
        case let .available(value) where !value.points.isEmpty:
            rootView.chartLoadingView.setLoading(false)
            rootView.chartView.bind(points: value.points)
            rootView.chartView.isHidden = false
            rootView.chartStatusLabel.text = nil
        case .none:
            rootView.chartLoadingView.setLoading(true)
            rootView.chartView.isHidden = true
            rootView.chartStatusLabel.text = nil
        default:
            rootView.chartLoadingView.setLoading(false)
            rootView.chartView.isHidden = true
            rootView.chartStatusLabel.text = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorUiPositionHistoryUnavailable()
        }
    }
}

extension SubtensorPositionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded { setupLocalization() }
    }
}
