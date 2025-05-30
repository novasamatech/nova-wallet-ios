import UIKit
import Foundation_iOS

final class MessageSheetHWAddressContent: UIView, MessageSheetContentProtocol {
    typealias ContentViewModel = [ViewModelItem]
    
    private var contentView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        font = .regularFootnote
        textColor = R.color.colorTextSecondary()
        textAlignment = .center
        numberOfLines = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(messageSheetContent: ContentViewModel?, locale _: Locale) {
        contentView?.removeFromSuperview()
    }
}

extension MessageSheetHWAddressContent {
    struct ViewModelItem {
        let scheme: HardwareWalletAddressScheme
        let address: AccountAddress
    }
}
