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

    let claimActionButton: TriangularedButton = .create { view in
        view.imageWithTitleView?.titleFont = .semiBoldSubheadline
        view.applyEnabledStyle()
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
        addSubview(claimActionButton)

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
        claimActionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.actionBottomInset)
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
        claimActionButton.imageWithTitleView?.title = viewModel.actionTitle

        viewModel.assetIcon.loadImage(
            on: assetImageView,
            targetSize: CGSize(width: 44.0, height: 44.0),
            animated: true
        )

        animationView.play { [weak self] _ in
        }
    }
}
