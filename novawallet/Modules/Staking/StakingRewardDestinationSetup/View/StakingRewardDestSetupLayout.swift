import UIKit
import SnapKit

final class StakingRewardDestSetupLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        return view
    }()

    let restakeOptionView = RewardSelectionView()
    let payoutOptionView = RewardSelectionView()
    let accountView = WalletAccountSelectionView()

    let networkFeeView = UIFactory.default.createNetworkFeeView()
    let actionButton: TriangularedButton = UIFactory.default.createMainActionButton()
    let learnMoreView = LinkCellView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()
        setupPayoutAccountShown(false)

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        networkFeeView.locale = locale

        learnMoreView.titleView.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingRewardsDestinationTitle()

        learnMoreView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingAboutRewards()

        restakeOptionView.titleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingRestakeTitle_v2_2_0()

        payoutOptionView.titleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingPayoutTitle_v2_2_0()

        accountView.titleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingRewardPayoutAccount()

        actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonContinue()
    }

    func setupPayoutAccountShown(_ isShown: Bool) {
        accountView.isHidden = !isShown

        let spacing = isShown ? 16.0 : 0.0

        contentView.stackView.setCustomSpacing(spacing, after: payoutOptionView)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.height.equalTo(44.0)
        }

        contentView.stackView.addArrangedSubview(restakeOptionView)
        restakeOptionView.snp.makeConstraints { make in
            make.height.equalTo(56.0)
        }

        contentView.stackView.setCustomSpacing(12.0, after: restakeOptionView)

        contentView.stackView.addArrangedSubview(payoutOptionView)
        payoutOptionView.snp.makeConstraints { make in
            make.height.equalTo(56.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: payoutOptionView)

        contentView.stackView.addArrangedSubview(accountView)

        contentView.stackView.addArrangedSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
