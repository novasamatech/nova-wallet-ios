import Foundation
import CommonWallet
import UIKit
import SoraUI

final class ReceiveHeaderView: UIView, AdaptiveDesignable {
    let accountControl = ChainAccountControl()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .p0Paragraph
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    var actionCommand: WalletCommandProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()

        accountControl.addTarget(self, action: #selector(actionReceive), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(accountControl)
        accountControl.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(16.0)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.top.equalTo(accountControl.snp.bottom).offset(46.0 * designScaleRatio.width)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
        }
    }

    @objc func actionReceive() {
        try? actionCommand?.execute()
    }
}
