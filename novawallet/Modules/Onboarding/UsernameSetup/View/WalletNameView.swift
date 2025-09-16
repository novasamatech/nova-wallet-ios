import UIKit

final class WalletNameView: UIView {
    let backgroundCardView = GladingCardView()

    let logoView: UIImageView = .create { imageView in
        imageView.image = R.image.novaCardLogo()
    }

    let walletNameTitleLabel: UILabel = .create { label in
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
    }

    let inputBackgroundView: OverlayBlurBackgroundView = .create { view in
        view.sideLength = 12
        view.borderType = .none
        view.overlayView.fillColor = R.color.colorBlockBackground()!
        view.overlayView.strokeColor = R.color.colorCardActionsBorder()!
        view.overlayView.strokeWidth = 1
        view.blurView?.alpha = 0.5
    }

    let inputGladingView: GladingRectView = .create { view in
        view.bind(model: .cardActionsStrokeGlading)
    }

    let walletNameInputView: TextInputView = .create { view in
        view.roundedBackgroundView?.apply(style: .inputStrokeOnCardEditing)
    }

    private var badgeView: BorderedIconLabelView?

    var locale = Locale.current {
        didSet {
            setupLocalization()
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

    func setBadge(viewModel: TitleIconViewModel) {
        let badgeView = setupBadgeView()
        badgeView.bind(viewModel: viewModel)
    }

    private func setupBadgeView() -> BorderedIconLabelView {
        if let badgeView {
            return badgeView
        }

        let view: BorderedIconLabelView = .create { view in
            view.backgroundView.apply(style: .chipsOnCard)
            view.backgroundView.cornerRadius = 6
            view.iconDetailsView.detailsLabel.apply(style: .semiboldCaps1ChipText)
            view.iconDetailsView.detailsLabel.numberOfLines = 1
            view.iconDetailsView.spacing = 6
            view.contentInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 8)
        }

        addSubview(view)

        view.snp.makeConstraints { make in
            make.trailing.top.equalToSuperview().inset(12)
        }

        badgeView = view

        return view
    }

    private func setupLocalization() {
        walletNameTitleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletUsernameSetupChooseTitle_v2_2_0()

        let placeholder = NSAttributedString(
            string: R.string(preferredLanguages: locale.rLanguages).localizable.walletNameInputPlaceholder(),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        walletNameInputView.textField.attributedPlaceholder = placeholder
    }

    private func setupLayout() {
        addSubview(backgroundCardView)
        backgroundCardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(logoView)
        logoView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(12)
        }

        addSubview(inputBackgroundView)
        inputBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(12)
            make.height.equalTo(48)
        }

        inputBackgroundView.addSubview(inputGladingView)
        inputGladingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        inputBackgroundView.addSubview(walletNameInputView)
        walletNameInputView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(walletNameTitleLabel)
        walletNameTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(inputBackgroundView.snp.top).offset(-8)
        }
    }
}
