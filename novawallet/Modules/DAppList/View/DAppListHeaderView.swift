import UIKit
import SoraUI

final class DAppListHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let accountButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconStyle()
        return button
    }()

    let decorationView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12.0
        view.clipsToBounds = true
        view.image = R.image.imageDapps()
        return view
    }()

    let decorationTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let decorationSubtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p2Paragraph
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(accountButton)
        accountButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10.0)
            make.trailing.equalToSuperview()
            make.size.equalTo(UIConstants.navigationAccountIconSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalTo(accountButton.snp.leading).offset(-8.0)
            make.centerY.equalTo(accountButton.snp.centerY)
        }

        addSubview(decorationView)
        decorationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(accountButton.snp.bottom).offset(16.0)
            make.height.equalTo(162.0)
            make.bottom.equalToSuperview()
        }

        decorationView.addSubview(decorationTitleLabel)
        decorationTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(20.0)
        }

        decorationView.addSubview(decorationSubtitleLabel)
        decorationSubtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(decorationTitleLabel.snp.bottom).offset(8.0)
        }
    }
}
