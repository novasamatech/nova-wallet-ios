import UIKit
import SoraUI

final class StakingClaimableRewardView: UIView {
    let backgroundView: OverlayBlurBackgroundView = .create { view in
        view.sideLength = 12
        view.borderType = .none
        view.overlayView.fillColor = R.color.colorBlockBackground()!
        view.overlayView.strokeColor = R.color.colorCardActionsBorder()!
        view.overlayView.strokeWidth = 1
        view.blurView?.alpha = 0.5
    }

    let contentView: GenericTitleValueView<MultiValueView, TriangularedButton> = .create { view in
        view.titleView.valueTop.apply(style: .regularSubhedlinePrimary)
        view.titleView.valueTop.textAlignment = .left
        view.titleView.valueBottom.apply(style: .footnoteSecondary)
        view.titleView.valueBottom.textAlignment = .left
        view.titleView.spacing = 0.0

        view.valueView.applyDefaultStyle()
        view.valueView.contentInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    }

    var rewardView: MultiValueView {
        contentView.titleView
    }

    var actionButton: TriangularedButton {
        contentView.valueView
    }

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 70)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: LoadableViewModelState<StakingRewardViewModel.ClaimableRewards>) {
        stopLoadingIfNeeded()

        switch viewModel {
        case let .loaded(claimableViewModel), let .cached(claimableViewModel):
            rewardView.bind(
                topValue: claimableViewModel.balance.amount,
                bottomValue: claimableViewModel.balance.price
            )

            if claimableViewModel.canClaim {
                actionButton.applyEnabledStyle()
                actionButton.isEnabled = true
            } else {
                actionButton.applyTranslucentDisabledStyle()
                actionButton.isEnabled = false
            }

        case .loading:
            startLoadingIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}

extension StakingClaimableRewardView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [rewardView.valueTop, rewardView.valueBottom, actionButton]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: 16, y: 21),
                size: CGSize(width: 90, height: 10)
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: 16, y: 41),
                size: CGSize(width: 43, height: 8)
            )
        ]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

extension StakingClaimableRewardView: SkeletonLoadable {
    func didDisappearSkeleton() {
        if isLoading {
            skeletonView?.stopSkrulling()
        }
    }

    func didAppearSkeleton() {
        if isLoading {
            skeletonView?.restartSkrulling()
        }
    }

    func didUpdateSkeletonLayout() {
        if isLoading {
            updateLoadingState()
            skeletonView?.stopSkrulling()
        }
    }
}
