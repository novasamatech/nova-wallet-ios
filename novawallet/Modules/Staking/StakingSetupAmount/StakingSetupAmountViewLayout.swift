import UIKit
import UIKit_iOS

final class StakingSetupAmountViewLayout: SCLoadableActionLayoutView {
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

    var stakingTypeView: BackgroundedContentControl = StakingTypeAccountView(frame: .zero)

    var actionButton: TriangularedButton {
        genericActionView.actionButton
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

        addArrangedSubview(amountView, spacingAfter: 8)
        amountView.snp.makeConstraints {
            $0.height.equalTo(Constants.amountHeight)
        }

        addArrangedSubview(amountInputView, spacingAfter: Constants.verticalSpacing)
        amountInputView.snp.makeConstraints {
            $0.height.equalTo(Constants.amountInputHeight)
        }

        addArrangedSubview(stakingTypeView, spacingAfter: Constants.verticalSpacing)

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

            estimatedRewardsView.stopLoadingIfNeeded()

            switch viewModel {
            case let .cached(value), let .loaded(value):
                setSelectedStaking(
                    viewModel: viewModel.map(with: { $0.type }),
                    canProceed: value.shouldEnableSelection
                )

                estimatedRewardsView.detailsTitleLabel.text = value.maxApy
            case .loading:
                setSelectedStaking(viewModel: .loading, canProceed: false)
                estimatedRewardsView.startLoadingIfNeeded()
            }

        } else {
            stakingTypeView.isHidden = true
            estimatedRewardsView.isHidden = true
        }
    }

    private func setSelectedStaking(
        viewModel: LoadableViewModelState<StakingTypeViewModel.TypeModel>,
        canProceed: Bool
    ) {
        switch viewModel {
        case let .cached(value), let .loaded(value):
            if let accountTypeViewModel = mapAccountViewModel(from: value) {
                setStakingAccountType(
                    viewModel: viewModel.map { _ in accountTypeViewModel },
                    canProceed: canProceed
                )
            } else if let validatorViewModel = mapValidatorViewModel(from: value) {
                setStakingValidatorType(
                    viewModel: viewModel.map(with: { _ in validatorViewModel }),
                    canProceed: canProceed
                )
            }
        case .loading:
            setStakingAccountType(viewModel: .loading, canProceed: canProceed)
        }
    }

    private func mapAccountViewModel(from viewModel: StakingTypeViewModel.TypeModel) -> StakingTypeAccountViewModel? {
        switch viewModel {
        case let .recommended(viewModel):
            return StakingTypeAccountViewModel(
                imageViewModel: nil,
                title: viewModel.title,
                subtitle: viewModel.subtitle,
                isRecommended: true
            )
        case let .pools(viewModel):
            return StakingTypeAccountViewModel(
                imageViewModel: viewModel.icon,
                title: viewModel.title,
                subtitle: viewModel.subtitle,
                isRecommended: viewModel.isRecommended
            )
        case .direct:
            return nil
        }
    }

    private func mapValidatorViewModel(
        from viewModel: StakingTypeViewModel.TypeModel
    ) -> DirectStakingTypeAccountViewModel? {
        switch viewModel {
        case .recommended, .pools:
            return nil
        case let .direct(validatorViewModel):
            return DirectStakingTypeAccountViewModel(
                count: validatorViewModel.count,
                title: validatorViewModel.title,
                subtitle: validatorViewModel.subtitle,
                isRecommended: validatorViewModel.isRecommended
            )
        }
    }

    private func setStakingAccountType(
        viewModel: LoadableViewModelState<StakingTypeAccountViewModel>,
        canProceed: Bool
    ) {
        let typeView: StakingTypeAccountView

        if let currentTypeView = stakingTypeView as? StakingTypeAccountView {
            typeView = currentTypeView
        } else {
            stakingTypeView.removeFromSuperview()

            typeView = StakingTypeAccountView(frame: .zero)
            insertArrangedSubview(typeView, after: amountInputView, spacingAfter: Constants.verticalSpacing)

            stakingTypeView = typeView
        }

        typeView.canProceed = canProceed

        typeView.stopLoadingIfNeeded()

        switch viewModel {
        case let .cached(value), let .loaded(value):
            typeView.bind(viewModel: value)
        case .loading:
            typeView.startLoadingIfNeeded()
        }
    }

    private func setStakingValidatorType(
        viewModel: LoadableViewModelState<DirectStakingTypeAccountViewModel>,
        canProceed: Bool
    ) {
        let typeView: StakingTypeValidatorView

        if let currentTypeView = stakingTypeView as? StakingTypeValidatorView {
            typeView = currentTypeView
        } else {
            stakingTypeView.removeFromSuperview()

            typeView = StakingTypeValidatorView(frame: .zero)
            insertArrangedSubview(typeView, after: amountInputView, spacingAfter: Constants.verticalSpacing)

            stakingTypeView = typeView
        }

        typeView.canProceed = canProceed

        typeView.stopLoadingIfNeeded()

        switch viewModel {
        case let .cached(value), let .loaded(value):
            typeView.bind(viewModel: value)
        case .loading:
            typeView.startLoadingIfNeeded()
        }
    }
}

extension StakingSetupAmountViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)
        static let amountHeight: CGFloat = 18
        static let amountInputHeight: CGFloat = 64
        static let estimatedRewardsHeight: CGFloat = 44
        static let verticalSpacing: CGFloat = 16
    }
}
