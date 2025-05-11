import UIKit

final class NavigationRootViewLayout: UIView {
    let titleView = WWalletSwitchControl()

    let walletConnectBarItem: UIBarButtonItem = .create { item in
        item.style = .plain
        item.image = R.image.iconWalletConnectNormal()
    }

    let settingsBarItem: UIBarButtonItem = .create { item in
        item.style = .plain
        item.image = R.image.iconSettings()?.tinted(with: R.color.colorIconChip()!)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
