import UIKit

final class WalletConnectViewLayout: UIView {
    let scanItem = UIBarButtonItem(
        image: R.image.iconScanQr()!,
        style: .plain,
        target: nil,
        action: nil
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()!
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
