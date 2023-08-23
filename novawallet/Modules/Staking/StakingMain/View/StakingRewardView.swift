import UIKit
import SoraUI
import SoraFoundation

final class StakingRewardView: UIView {
    let backgroundView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12.0
        view.clipsToBounds = true
        view.image = R.image.imageStakingReward()
        return view
    }()

    let totalRewardView = StakingTotalRewardView()
    private var claimableRewardView: StakingClaimableRewardView?

    var claimButton: TriangularedButton? { claimableRewardView?.actionButton }
    var filterView: BorderedActionControlView { totalRewardView.filterView }

    let stackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = 16
        view.isLayoutMarginsRelativeArrangement = true
        view.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 12, right: 16)
    }

    private var viewModel: LocalizableResource<StakingRewardViewModel>?

    var locale = Locale.current {
        didSet {
            setupLocalization()
            applyViewModel()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: LocalizableResource<StakingRewardViewModel>) {
        self.viewModel = viewModel
        applyViewModel()
    }

    private func applyViewModel() {
        guard let viewModel = viewModel?.value(for: locale) else {
            totalRewardView.bind(totalRewards: .loading, filter: nil)
            clearClaimableRewardsView()
            return
        }

        totalRewardView.bind(totalRewards: viewModel.totalRewards, filter: viewModel.filter)

        if let claimableRewards = viewModel.claimableRewards {
            setupClaimableRewardsViewIfNeeded()
            claimableRewardView?.bind(viewModel: claimableRewards)
        } else {
            clearClaimableRewardsView()
        }

        setNeedsLayout()
    }

    func setupClaimableRewardsViewIfNeeded() {
        guard claimableRewardView == nil else {
            return
        }

        let view = StakingClaimableRewardView()
        stackView.addArrangedSubview(view)
        claimableRewardView = view

        setupClaimButtonLocalization()
    }

    func clearClaimableRewardsView() {
        claimableRewardView?.removeFromSuperview()
        claimableRewardView = nil
    }

    private func setupLocalization() {
        let languages = locale.rLanguages

        totalRewardView.titleLabel.text = R.string.localizable.stakingRewardsTitle(preferredLanguages: languages)
        setupClaimButtonLocalization()
    }

    private func setupClaimButtonLocalization() {
        claimButton?.imageWithTitleView?.title = R.string.localizable.stakingClaimRewards(
            preferredLanguages: locale.rLanguages
        )
        claimButton?.invalidateLayout()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.addArrangedSubview(totalRewardView)
    }
}

extension StakingRewardView: SkeletonLoadable {
    func didDisappearSkeleton() {
        totalRewardView.didDisappearSkeleton()
        claimableRewardView?.didDisappearSkeleton()
    }

    func didAppearSkeleton() {
        totalRewardView.didAppearSkeleton()
        claimableRewardView?.didAppearSkeleton()
    }

    func didUpdateSkeletonLayout() {
        totalRewardView.didUpdateSkeletonLayout()
        claimableRewardView?.didUpdateSkeletonLayout()
    }
}
