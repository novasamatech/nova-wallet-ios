import UIKit
import UIKit_iOS

final class SubtensorPositionViewLayout: UIView {
    let backgroundView = MultigradientView.background
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 20, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 16
        return view
    }()

    let summaryCard = UIView()
    let captionLabel = UILabel()
    let amountLabel = UILabel()
    let fiatLabel = UILabel()
    let statusLabel = UILabel()
    let rewardTitleLabel = UILabel()
    let rewardValueLabel = UILabel()
    let worthTitleLabel = UILabel()
    let worthValueLabel = UILabel()
    let holdNoticeCard = UIView()
    let holdNoticeLabel = UILabel()

    let rootActionCard = UIView()
    let addStakeButton = UIButton(type: .system)
    let unstakeButton = UIButton(type: .system)

    let chartView = SubtensorSubnetPriceChartView()
    let chartLoadingView = SubtensorChartLoadingView()
    let chartStatusLabel = UILabel()
    let periodButtons: [UIButton] = ["1D", "7D", "1M", "3M", "1Y"].map { title in
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .caption1
        button.setTitleColor(R.color.colorTextSecondary(), for: .normal)
        button.layer.cornerRadius = 8
        return button
    }

    let chartContainer = UIView()
    let periodStack = UIStackView()

    let validatorCard = UIView()
    let validatorCaption = UILabel()
    let validatorLabel = UILabel()
    let sellButton = UIButton(type: .system)
    let buyButton = TriangularedButton()
    let bottomBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupStyles()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setRootMode(_ isRoot: Bool) {
        rootActionCard.isHidden = !isRoot
        chartContainer.isHidden = isRoot
        periodStack.isHidden = isRoot
        bottomBar.isHidden = isRoot
        worthTitleLabel.isHidden = isRoot
        worthValueLabel.isHidden = isRoot
        worthTitleLabel.snp.updateConstraints { make in
            make.top.equalTo(rewardTitleLabel.snp.bottom).offset(isRoot ? 0 : 22)
        }
    }

    private func setupStyles() {
        [summaryCard, rootActionCard, validatorCard].forEach { card in
            card.backgroundColor = R.color.colorBlockBackground()
            card.layer.cornerRadius = 12
        }
        holdNoticeCard.backgroundColor = R.color.colorWarningBlockBackground()
        holdNoticeCard.layer.cornerRadius = 12
        holdNoticeCard.isHidden = true
        holdNoticeLabel.font = .regularFootnote
        holdNoticeLabel.textColor = R.color.colorTextPrimary()
        holdNoticeLabel.numberOfLines = 0
        [captionLabel, rewardTitleLabel, worthTitleLabel, validatorCaption].forEach { label in
            label.font = .regularFootnote
            label.textColor = R.color.colorTextSecondary()
        }
        amountLabel.font = .boldTitle1
        amountLabel.textColor = R.color.colorTextPrimary()
        fiatLabel.font = .regularFootnote
        fiatLabel.textColor = R.color.colorTextSecondary()
        rewardValueLabel.font = .semiBoldFootnote
        rewardValueLabel.textColor = R.color.colorTextPrimary()
        worthValueLabel.font = .semiBoldFootnote
        worthValueLabel.textColor = R.color.colorTextPrimary()
        statusLabel.font = .caption1
        statusLabel.textColor = R.color.colorTextPositive()
        validatorLabel.font = .semiBoldSubheadline
        validatorLabel.textColor = R.color.colorTextPrimary()

        [addStakeButton, unstakeButton].forEach { button in
            button.contentHorizontalAlignment = .left
            button.titleLabel?.font = .regularSubheadline
            button.setTitleColor(R.color.colorTextPrimary(), for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        }
        chartStatusLabel.font = .regularFootnote
        chartStatusLabel.textColor = R.color.colorTextSecondary()
        chartStatusLabel.textAlignment = .center
        periodStack.axis = .horizontal
        periodStack.distribution = .fillEqually
        periodButtons.forEach(periodStack.addArrangedSubview)

        sellButton.backgroundColor = R.color.colorBlockBackground()
        sellButton.layer.cornerRadius = 12
        sellButton.setTitleColor(R.color.colorTextPrimary(), for: .normal)
        buyButton.applyDefaultStyle()
        buyButton.invalidateLayout()
        bottomBar.backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    private func setupLayout() {
        setupFrame()
        setupSummaryCard()
        setupRootActionCard()
        setupChart()
        setupValidatorCard()
    }

    private func setupFrame() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        addSubview(containerView)
        addSubview(bottomBar)
        bottomBar.addSubview(sellButton)
        bottomBar.addSubview(buyButton)
        bottomBar.snp.makeConstraints { make in make.leading.trailing.bottom.equalToSuperview() }
        sellButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(16)
            make.width.equalTo(buyButton)
            make.height.equalTo(52)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(12)
        }
        buyButton.snp.makeConstraints { make in
            make.leading.equalTo(sellButton.snp.trailing).offset(16)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(sellButton)
            make.height.equalTo(52)
        }
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupSummaryCard() {
        summaryCard.addSubview(captionLabel)
        summaryCard.addSubview(amountLabel)
        summaryCard.addSubview(fiatLabel)
        summaryCard.addSubview(statusLabel)
        summaryCard.addSubview(rewardTitleLabel)
        summaryCard.addSubview(rewardValueLabel)
        summaryCard.addSubview(worthTitleLabel)
        summaryCard.addSubview(worthValueLabel)
        captionLabel.snp.makeConstraints { make in make.leading.top.equalToSuperview().inset(16) }
        amountLabel.snp.makeConstraints { make in
            make.top.equalTo(captionLabel.snp.bottom).offset(6)
            make.leading.equalTo(captionLabel)
        }
        fiatLabel.snp.makeConstraints { make in
            make.top.equalTo(amountLabel.snp.bottom).offset(4)
            make.leading.equalTo(captionLabel)
        }
        statusLabel.snp.makeConstraints { make in
            make.trailing.top.equalToSuperview().inset(16)
        }
        rewardTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(captionLabel)
            make.top.equalTo(fiatLabel.snp.bottom).offset(22)
        }
        rewardValueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(rewardTitleLabel)
        }
        worthTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(captionLabel)
            make.top.equalTo(rewardTitleLabel.snp.bottom).offset(22)
            make.bottom.equalToSuperview().inset(16)
        }
        worthValueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(worthTitleLabel)
        }
        containerView.stackView.addArrangedSubview(summaryCard)
    }

    private func setupRootActionCard() {
        holdNoticeCard.addSubview(holdNoticeLabel)
        holdNoticeLabel.snp.makeConstraints { make in make.edges.equalToSuperview().inset(16) }
        containerView.stackView.addArrangedSubview(holdNoticeCard)

        rootActionCard.addSubview(addStakeButton)
        rootActionCard.addSubview(unstakeButton)
        addStakeButton.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(48)
        }
        unstakeButton.snp.makeConstraints { make in
            make.top.equalTo(addStakeButton.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(48)
        }
        containerView.stackView.addArrangedSubview(rootActionCard)
    }

    private func setupChart() {
        chartContainer.addSubview(chartView)
        chartContainer.addSubview(chartLoadingView)
        chartContainer.addSubview(chartStatusLabel)
        chartView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chartLoadingView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chartStatusLabel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chartContainer.snp.makeConstraints { make in make.height.equalTo(208) }
        containerView.stackView.addArrangedSubview(chartContainer)
        periodStack.snp.makeConstraints { make in make.height.equalTo(32) }
        containerView.stackView.addArrangedSubview(periodStack)
    }

    private func setupValidatorCard() {
        validatorCard.addSubview(validatorCaption)
        validatorCard.addSubview(validatorLabel)
        validatorCaption.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(16)
        }
        validatorLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(validatorCaption)
        }
        containerView.stackView.addArrangedSubview(validatorCard)
    }
}
