import UIKit

final class StakingSetupAmountViewLayout: ScrollableContainerLayoutView {
    let amountView = TitleHorizontalMultiValueView()
    let amountInputView = NewAmountInputView()
    private var estimatedRewardsView: TitleHorizontalMultiValueView?
    private var stakingTypeView: StakingTypeView?

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

        addArrangedSubview(amountView, spacingAfter: 16)
        amountInputView.snp.makeConstraints {
            $0.height.equalTo(Constants.amountInputHeight)
        }
    }

    func setStakingType(viewModel: LoadableViewModelState<MultiValueView.Model>?) {
        if let viewModel = viewModel {
            if stakingTypeView == nil {
                let view = StakingTypeView(frame: .zero)
                addArrangedSubview(view, spacingAfter: 16)
                stakingTypeView = view
            }
            stakingTypeView?.bind(viewModel: viewModel)
        } else {
            stakingTypeView?.removeFromSuperview()
            stakingTypeView = nil
        }
    }

    func setEstimatedRewards(viewModel: LoadableViewModelState<TitleHorizontalMultiValueView.RewardModel>?) {
        if let viewModel = viewModel {
            if estimatedRewardsView == nil {
                let view = TitleHorizontalMultiValueView()
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
}

extension StakingSetupAmountViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        static let amountHeight: CGFloat = 34
        static let amountInputHeight: CGFloat = 64
        static let estimatedRewardsHeight: CGFloat = 44
    }
}
