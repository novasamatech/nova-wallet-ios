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
        view.spacing = 8.0
        view.detailsLabel.apply(style: .boldLargePrimary)
        view.iconWidth = 44.0
    }

    var assetImageView: UIImageView {
        amountView.imageView
    }

    var amountLabel: UILabel {
        amountView.detailsLabel
    }

    let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.5,
        options: [.curveEaseInOut]
    )

    lazy var controlStack = UIStackView.vStack(
        spacing: Constants.interButtonSpacing,
        [
            selectedWalletView,
            claimActionButton
        ]
    )

    let selectedWalletView: GenericMultiValueView<GiftClaimSelectedWalletView> = .create { view in
        view.spacing = 8
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

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
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
            make.top.equalTo(safeAreaLayoutGuide.snp.top).inset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        animationView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).inset(-16)
            make.leading.trailing.equalToSuperview().inset(47.5)
            make.height.equalTo(animationView.snp.width)
        }
        amountView.snp.makeConstraints { make in
            make.top.equalTo(animationView.snp.bottom).inset(-8)
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

    func animateContentDisappearance() {
        [
            titleLabel,
            amountView,
            claimActionButton
        ].forEach {
            disappearanceAnimator.animate(
                view: $0,
                completionBlock: nil
            )
        }
    }
}

// MARK: - Internal

extension GiftClaimViewLayout {
    func bind(viewModel: GiftClaimViewModel) {
        titleLabel.text = viewModel.title
        animationView.animation = viewModel.animation
        amountLabel.text = viewModel.amount
        claimActionButton.actionButton.imageWithTitleView?.title = viewModel.actionTitle

        viewModel.assetIcon.loadImage(
            on: assetImageView,
            targetSize: CGSize(width: 44.0, height: 44.0),
            animated: true
        )

        animationView.play(
            fromFrame: viewModel.animationFrameRange.startFrame,
            toFrame: viewModel.animationFrameRange.endFrame
        )

        selectedWalletControl.bind(viewModel: viewModel.)
    }

    func bind(animationFrameRange: LottieAnimationFrameRange) {
        animationView.play(
            fromFrame: animationFrameRange.startFrame,
            toFrame: animationFrameRange.endFrame
        )
    }
}

// MARK: - Constants

private extension GiftClaimViewLayout {
    enum Constants {
        static let interButtonSpacing: CGFloat = 24
    }
}
