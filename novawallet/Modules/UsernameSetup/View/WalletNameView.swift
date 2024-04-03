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

    let walletNameInputView = TextInputView()

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

    private func setupLocalization() {
        walletNameTitleLabel.text = R.string.localizable.walletUsernameSetupChooseTitle_v2_2_0(
            preferredLanguages: locale.rLanguages
        )

        let placeholder = NSAttributedString(
            string: R.string.localizable.walletNameInputPlaceholder(preferredLanguages: locale.rLanguages),
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

        addSubview(walletNameInputView)
        walletNameInputView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(12)
        }

        addSubview(walletNameTitleLabel)
        walletNameTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(walletNameInputView.snp.top).offset(-8)
        }
    }
}
