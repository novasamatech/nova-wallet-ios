import UIKit
import SoraUI

final class ParitySignerTxQrViewLayout: UIView, AdaptiveDesignable {
    enum Constants {
        static let qrContentInsets: CGFloat = 10.0
        static let defaultQrSize: CGFloat = 280.0
    }

    let accountDetailsView = WalletAccountActionView.createInfoView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .semiBoldBody
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let qrView = QRDisplayView()

    let timerLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.textAlignment = .center
        return label
    }()

    let helpButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        return button
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var qrSize: CGFloat {
        designScaleRatio.width * 280.0
    }

    var qrImageSize: CGFloat {
        min(qrSize - 2 * Constants.qrContentInsets, 0.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(helpButton)
        helpButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(continueButton.snp.top).offset(-16.0)
        }

        addSubview(accountDetailsView)
        accountDetailsView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(16.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        addSubview(qrView)
        qrView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(qrSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(qrView.snp.top).offset(-35.0)
        }

        addSubview(timerLabel)
        timerLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(qrView.snp.bottom).offset(24.0)
        }
    }
}
