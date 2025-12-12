import UIKit

final class ParitySignerTxScanViewLayout: QRScannerViewLayout {
    let timerLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        label.textAlignment = .center
        return label
    }()

    override func setupLayout(with settings: QRScannerViewSettings) {
        super.setupLayout(with: settings)

        addSubview(timerLabel)
        timerLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(qrFrameImageView.snp.bottom).offset(24.0)
        }
    }
}
