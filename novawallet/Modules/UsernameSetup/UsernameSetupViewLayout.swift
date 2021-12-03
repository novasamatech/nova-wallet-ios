import UIKit
import SnapKit
import SoraUI

final class UsernameSetupViewLayout: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    let containerView: TriangularedView = {
        let view = TriangularedView()
        view.sideLength = 10.0
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorGray()!
        view.highlightedStrokeColor = R.color.colorGray()!
        view.strokeWidth = 1.0
        return view
    }()

    let nameField: AnimatedTextField = {
        let textField = AnimatedTextField()
        textField.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 6.0, right: 16.0)
        textField.titleFont = .p2Paragraph
        textField.placeholderFont = .p1Paragraph
        textField.textFont = .p1Paragraph
        textField.titleColor = R.color.colorLightGray()!
        textField.placeholderColor = R.color.colorLightGray()!
        textField.textColor = R.color.colorWhite()
        textField.cursorColor = R.color.colorWhite()!
        textField.textField.enablesReturnKeyAutomatically = true
        return textField
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).inset(UIConstants.verticalTitleInset)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(24.0)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        containerView.addSubview(nameField)
        nameField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
