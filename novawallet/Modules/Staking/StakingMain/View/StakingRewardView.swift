import UIKit
import UIKit_iOS
import Foundation_iOS

final class StakingRewardView: UIView {
    let backgroundView: UIView = .create { view in
        view.backgroundColor = R.color.colorRewardsBackground()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let borderView: RoundedView = .create { view in
        view.applyStrokedBackgroundStyle()

        view.cornerRadius = 12
        view.strokeColor = R.color.colorContainerBorder()!
        view.strokeWidth = 1
    }

    let graphicsView = UIImageView()

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
            totalRewardView.bind(totalRewards: .loading, filter: nil, hasPrice: true)
            clearClaimableRewardsView()
            graphicsView.image = nil
            return
        }

        graphicsView.image = viewModel.graphics

        totalRewardView.bind(
            totalRewards: viewModel.totalRewards,
            filter: viewModel.filter,
            hasPrice: viewModel.hasPrice
        )

        if let claimableRewards = viewModel.claimableRewards {
            setupClaimableRewardsViewIfNeeded()
            claimableRewardView?.bind(viewModel: claimableRewards)
        } else {
            clearClaimableRewardsView()
        }

        invalidateIntrinsicContentSize()
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

        totalRewardView.titleLabel.text = R.string(preferredLanguages: languages).localizable.stakingRewardsTitle()
        setupClaimButtonLocalization()
    }

    private func setupClaimButtonLocalization() {
        claimButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingClaimRewards()
        claimButton?.invalidateLayout()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.addSubview(graphicsView)
        graphicsView.snp.makeConstraints { make in
            make.top.right.equalToSuperview()
        }

        addSubview(borderView)
        borderView.snp.makeConstraints { make in
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
