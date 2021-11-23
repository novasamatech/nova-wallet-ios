import UIKit
import SnapKit
import SoraUI

final class UsernameSetupViewLayout: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorGray()
        return label
    }()

    let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let nameField: AnimatedTextField = {
        let textField = AnimatedTextField()
        textField.titleFont = .h6Title
        textField.placeholderFont = .h5Title
        textField.textFont = .h5Title
        textField.titleColor = R.color.colorLightGray()!
        textField.placeholderColor = R.color.colorLightGray()!
        textField.textColor = R.color.colorWhite()
        textField.cursorColor = R.color.colorWhite()!
        return textField
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
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
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
        }

        addSubview(nameField)
        nameField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(32.0)
        }

        addSubview(captionLabel)
        captionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(nameField.snp.bottom).offset(12.0)
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
