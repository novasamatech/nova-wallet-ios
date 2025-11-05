import UIKit
import UIKit_iOS
import Lottie

final class GiftPrepareShareViewLayout: UIView {
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

    var configuration: GiftPrepareShareViewConfiguration = .share

    let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: 0.5,
        options: [.curveEaseInOut]
    )

    let shareActionButton: TriangularedButton = .create { view in
        view.imageWithTitleView?.iconImage = R.image.iconShare()
        view.imageWithTitleView?.titleFont = .semiBoldSubheadline
        view.applyEnabledStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    convenience init(configuration: GiftPrepareShareViewConfiguration) {
        self.init()
        self.configuration = configuration
        applyConfiguration()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension GiftPrepareShareViewLayout {
    func setupLayout() {
        addSubview(titleLabel)
        addSubview(animationView)
        addSubview(amountView)
        addSubview(shareActionButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).inset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        animationView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).inset(-32)
            make.leading.trailing.equalToSuperview().inset(47.5)
            make.height.equalTo(animationView.snp.width)
        }
        amountView.snp.makeConstraints { make in
            make.top.equalTo(animationView.snp.bottom).inset(-8)
            make.centerX.equalToSuperview()
        }
        shareActionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.actionBottomInset)
        }
    }

    func applyConfiguration() {
        titleLabel.alpha = configuration.titleInitialAlpha
        amountView.alpha = configuration.amountInitialViewAlpha
        shareActionButton.alpha = configuration.actionInitialAlpha
    }

    func didCompletePlayingGiftAnimation() {
        guard configuration.playAnimation else { return }

        animateContentAppearance()
    }

    func animateContentAppearance() {
        [
            titleLabel,
            amountView,
            shareActionButton
        ].forEach {
            appearanceAnimator.animate(
                view: $0,
                completionBlock: nil
            )
        }
    }
}

// MARK: - Internal

extension GiftPrepareShareViewLayout {
    func bind(viewModel: GiftPrepareViewModel) {
        titleLabel.text = viewModel.title
        animationView.animation = viewModel.animation
        amountLabel.text = viewModel.amount
        shareActionButton.imageWithTitleView?.title = viewModel.actionTitle

        viewModel.assetIcon.loadImage(
            on: assetImageView,
            targetSize: CGSize(width: 44.0, height: 44.0),
            animated: true
        )

        guard configuration.playAnimation else {
            animationView.currentProgress = 1.0
            return
        }

        animationView.play { [weak self] _ in
            self?.didCompletePlayingGiftAnimation()
        }
    }
}

enum GiftPrepareShareViewStyle {
    case share
    case prepareShare

    var congifuration: GiftPrepareShareViewConfiguration {
        switch self {
        case .share:
            GiftPrepareShareViewConfiguration.share
        case .prepareShare:
            GiftPrepareShareViewConfiguration.prepareShare
        }
    }
}

struct GiftPrepareShareViewConfiguration {
    let titleInitialAlpha: CGFloat
    let amountInitialViewAlpha: CGFloat
    let actionInitialAlpha: CGFloat
    let playAnimation: Bool

    static let share: GiftPrepareShareViewConfiguration = .init(
        titleInitialAlpha: 1.0,
        amountInitialViewAlpha: 1.0,
        actionInitialAlpha: 1.0,
        playAnimation: false
    )

    static let prepareShare: GiftPrepareShareViewConfiguration = .init(
        titleInitialAlpha: .zero,
        amountInitialViewAlpha: .zero,
        actionInitialAlpha: .zero,
        playAnimation: true
    )
}
