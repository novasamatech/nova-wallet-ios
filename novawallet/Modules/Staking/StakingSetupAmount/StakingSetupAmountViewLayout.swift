import UIKit

final class StakingSetupAmountViewLayout: ScrollableContainerLayoutView {
    let amountView: TitleHorizontalMultiValueView = .create {
        $0.titleView.apply(style: .footnoteSecondary)
        $0.detailsTitleLabel.apply(style: .footnoteSecondary)
        $0.detailsValueLabel.apply(style: .footnotePrimary)
    }

    let amountInputView = NewAmountInputView()
    let estimatedRewardsView: LoadableTitleHorizontalMultiValueView = .create { view in
        view.titleView.apply(style: .footnoteSecondary)
        view.detailsTitleLabel.apply(style: .semiboldFootnotePositive)
        view.detailsValueLabel.apply(style: .caption1Secondary)
    }

    let stakingTypeView = StakingTypeAccountView(frame: .zero)

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

        addArrangedSubview(stakingTypeView, spacingAfter: 16)

        addArrangedSubview(estimatedRewardsView)

        estimatedRewardsView.snp.makeConstraints {
            $0.height.equalTo(Constants.estimatedRewardsHeight)
        }

        stakingTypeView.isHidden = true
        estimatedRewardsView.isHidden = true
    }

    func setStakingType(viewModel: LoadableViewModelState<StakingTypeViewModel>?) {
        if let viewModel = viewModel {
            stakingTypeView.isHidden = false
            estimatedRewardsView.isHidden = false

            stakingTypeView.stopLoadingIfNeeded()
            estimatedRewardsView.stopLoadingIfNeeded()

            switch viewModel {
            case let .cached(value), let .loaded(value):
                let typeViewModel = StakingTypeAccountViewModel(
                    imageViewModel: value.icon,
                    title: value.title,
                    subtitle: value.subtitle,
                    isRecommended: value.isRecommended
                )

                stakingTypeView.bind(viewModel: typeViewModel)
                stakingTypeView.canProceed = value.shouldEnableSelection

                estimatedRewardsView.detailsTitleLabel.text = value.maxApy
            case .loading:
                stakingTypeView.startLoadingIfNeeded()
                estimatedRewardsView.startLoadingIfNeeded()
            }

        } else {
            stakingTypeView.isHidden = true
            estimatedRewardsView.isHidden = true
        }
    }
}

extension StakingSetupAmountViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)
        static let amountHeight: CGFloat = 18
        static let amountInputHeight: CGFloat = 64
        static let estimatedRewardsHeight: CGFloat = 44
    }
}
