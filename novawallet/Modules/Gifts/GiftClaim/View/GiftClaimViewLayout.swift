import UIKit
import UIKit_iOS
import Lottie

final class GiftClaimViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle1Primary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    let animationView = LottieAnimationView()

    let amountView: IconDetailsView = .create { view in
        view.spacing = Constants.amountViewSpacing
        view.detailsLabel.apply(style: .boldLargePrimary)
        view.iconWidth = Constants.assetIconSize
    }

    var assetImageView: UIImageView {
        amountView.imageView
    }

    var amountLabel: UILabel {
        amountView.detailsLabel
    }

    lazy var controlStack = UIStackView.vStack(
        spacing: Constants.interButtonSpacing,
        [
            selectedWalletView,
            claimActionButton
        ]
    )

    let selectedWalletView: GenericMultiValueView<GiftClaimSelectedWalletView> = .create { view in
        view.spacing = Constants.selectedWalletViewSpacing
        view.valueTop.apply(style: .footnoteSecondary)
        view.valueTop.textAlignment = .left
    }

    var walletViewHintLabel: UILabel {
        selectedWalletView.valueTop
    }

    var selectedWalletControl: GiftClaimSelectedWalletView {
        selectedWalletView.valueBottom
    }

    let claimActionButton: LoadableActionView = .create { view in
        view.actionButton.imageWithTitleView?.titleFont = .semiBoldSubheadline
        view.actionButton.applyEnabledStyle()
    }

    lazy var appearingViews: [UIView] = [
        titleLabel,
        amountView,
        controlStack
    ]

    let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: Constants.appearanceAnimatorFromAlpha,
        to: Constants.appearanceAnimatorToAlpha,
        duration: Constants.fadeAnimatorDuration,
        options: [.curveEaseInOut]
    )

    let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: Constants.disappearanceAnimatorFromAlpha,
        to: Constants.disappearanceAnimatorToAlpha,
        duration: Constants.fadeAnimatorDuration,
        options: [.curveEaseInOut]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension GiftClaimViewLayout {
    func setupLayout() {
        addSubview(titleLabel)
        addSubview(animationView)
        addSubview(amountView)
        addSubview(controlStack)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).inset(Constants.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        animationView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).inset(-Constants.animationViewTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.animationViewHorizontalInset)
            make.height.equalTo(animationView.snp.width)
        }
        amountView.snp.makeConstraints { make in
            make.top.equalTo(animationView.snp.bottom).inset(-Constants.amountViewTopOffset)
            make.centerX.equalToSuperview()
        }
        controlStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.actionBottomInset)
        }
        claimActionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }
        selectedWalletControl.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    func setupStyle() {
        appearingViews.forEach { $0.alpha = 0 }
    }

    func animateContentAppearance() {
        appearingViews.forEach {
            appearanceAnimator.animate(
                view: $0,
                completionBlock: nil
            )
        }
    }

    func animateContentDisappearance() {
        appearingViews.forEach {
            disappearanceAnimator.animate(
                view: $0,
                completionBlock: nil
            )
        }
    }

    func bind(_ controlsViewModel: GiftClaimViewModel.ControlsViewModel) {
        selectedWalletControl.bind(viewModel: controlsViewModel.selectedWalletViewModel)

        switch controlsViewModel.claimActionViewModel {
        case let .enabled(title):
            claimActionButton.actionButton.imageWithTitleView?.title = title
            claimActionButton.actionButton.applyDefaultStyle()
            claimActionButton.isUserInteractionEnabled = true
        case let .disabled(title):
            claimActionButton.actionButton.imageWithTitleView?.title = title
            claimActionButton.actionButton.applyDisabledStyle()
            claimActionButton.isUserInteractionEnabled = false
        case .none:
            claimActionButton.isHidden = true
        }
    }

    func bind(
        _ animationViewModel: LottieAnimation,
        animationFrameRange: LottieAnimationFrameRange
    ) {
        guard animationView.currentFrame <= animationFrameRange.startFrame else {
            return
        }

        animationView.animation = animationViewModel

        animationView.play(
            fromFrame: animationFrameRange.startFrame,
            toFrame: animationFrameRange.endFrame
        ) { [weak self] _ in
            self?.animateContentAppearance()
        }
    }
}

// MARK: - Internal

extension GiftClaimViewLayout {
    func bind(viewModel: GiftClaimViewModel) {
        titleLabel.text = viewModel.title
        amountLabel.text = viewModel.amount

        viewModel.assetIcon.loadImage(
            on: assetImageView,
            targetSize: CGSize(
                width: Constants.assetIconSize,
                height: Constants.assetIconSize
            ),
            animated: true
        )

        bind(
            viewModel.animation,
            animationFrameRange: viewModel.animationFrameRange
        )

        bind(viewModel.controlsViewModel)
    }

    func bind(animationFrameRange: LottieAnimationFrameRange) {
        animationView.play(
            fromFrame: animationFrameRange.startFrame,
            toFrame: animationFrameRange.endFrame
        ) { [weak self] _ in
            self?.animateContentDisappearance()
        }
    }
}

// MARK: - Constants

private extension GiftClaimViewLayout {
    enum Constants {
        static let interButtonSpacing: CGFloat = 24
        static let amountViewSpacing: CGFloat = 8.0
        static let assetIconSize: CGFloat = 44.0
        static let disappearanceAnimatorFromAlpha: CGFloat = 1.0
        static let disappearanceAnimatorToAlpha: CGFloat = 0.0
        static let appearanceAnimatorFromAlpha: CGFloat = 0.0
        static let appearanceAnimatorToAlpha: CGFloat = 1.0
        static let fadeAnimatorDuration: TimeInterval = 0.5
        static let selectedWalletViewSpacing: CGFloat = 8
        static let titleTopInset: CGFloat = 24
        static let animationViewTopOffset: CGFloat = 16
        static let animationViewHorizontalInset: CGFloat = 47.5
        static let amountViewTopOffset: CGFloat = 8
    }
}
