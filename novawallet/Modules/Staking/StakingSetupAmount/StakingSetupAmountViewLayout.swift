import UIKit

final class StakingSetupAmountViewLayout: ScrollableContainerLayoutView {
    let amountView: TitleHorizontalMultiValueView = .create {
        $0.titleView.apply(style: .footnoteSecondary)
        $0.detailsTitleLabel.apply(style: .footnoteSecondary)
        $0.detailsValueLabel.apply(style: .footnotePrimary)
    }

    let amountInputView = NewAmountInputView()
    private var estimatedRewardsView: TitleHorizontalMultiValueView?
    private(set) var stakingTypeView: StakingTypeAccountView?

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = Constants.contentInsets

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addArrangedSubview(amountView, spacingAfter: 8)
        amountView.snp.makeConstraints {
            $0.height.equalTo(Constants.amountHeight)
        }

        addArrangedSubview(amountInputView, spacingAfter: 16)
        amountInputView.snp.makeConstraints {
            $0.height.equalTo(Constants.amountInputHeight)
        }
    }

    func setEstimatedRewards(viewModel: LoadableViewModelState<TitleHorizontalMultiValueView.Model>?) {
        if let viewModel = viewModel {
            if estimatedRewardsView == nil {
                let view = TitleHorizontalMultiValueView()
                setup(estimatedRewardsView: view)
                addArrangedSubview(view)
                view.snp.makeConstraints {
                    $0.height.equalTo(Constants.estimatedRewardsHeight)
                }
                estimatedRewardsView = view
            }
            estimatedRewardsView?.bind(viewModel: viewModel)
        } else {
            estimatedRewardsView?.removeFromSuperview()
            estimatedRewardsView = nil
        }
    }

    func setStakingType(viewModel: LoadableViewModelState<StakingTypeViewModel>?) {
        if let viewModel = viewModel {
            if stakingTypeView == nil {
                let view = StakingTypeAccountView(frame: .zero)
                addArrangedSubview(view, spacingAfter: 16)
                stakingTypeView = view
            }
            stakingTypeView?.bind(stakingTypeViewModel: viewModel)
        } else {
            stakingTypeView?.removeFromSuperview()
            stakingTypeView = nil
        }
    }

    private func setup(estimatedRewardsView: TitleHorizontalMultiValueView) {
        estimatedRewardsView.titleView.apply(style: .footnoteSecondary)
        estimatedRewardsView.detailsTitleLabel.apply(style: .semiboldFootnotePositive)
        estimatedRewardsView.detailsValueLabel.apply(style: .caption1Secondary)
    }
}

extension StakingSetupAmountViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        static let amountHeight: CGFloat = 18
        static let amountInputHeight: CGFloat = 64
        static let estimatedRewardsHeight: CGFloat = 44
    }
}
