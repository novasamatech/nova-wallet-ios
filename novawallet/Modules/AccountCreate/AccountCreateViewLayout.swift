import Foundation
import UIKit
import SoraUI
import Starscream

final class AccountCreateViewLayout: UIView {
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

    let mnemonicBackroundView: RoundedView = UIFactory.default.createRoundedBackgroundView(filled: true)

    let mnemonicFieldTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let mnemonicFieldContentLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .clear
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
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

        addSubview(mnemonicBackroundView)
        mnemonicBackroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20.0)
            make.height.greaterThanOrEqualTo(UIConstants.triangularedViewHeight)
        }

        addSubview(mnemonicFieldTitleLabel)
        mnemonicFieldTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(mnemonicBackroundView).inset(UIConstants.horizontalInset)
            make.top.equalTo(mnemonicBackroundView.snp.top).offset(UIConstants.verticalTitleInset)
        }

        addSubview(mnemonicFieldContentLabel)
        mnemonicFieldContentLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(mnemonicBackroundView).inset(UIConstants.horizontalInset)
            make.top.equalTo(mnemonicFieldTitleLabel.snp.bottom).offset(1.0)
            make.bottom.equalTo(mnemonicBackroundView.snp.bottom).inset(12.0)
        }

        addSubview(captionLabel)
        captionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(mnemonicBackroundView.snp.bottom).offset(12.0)
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
