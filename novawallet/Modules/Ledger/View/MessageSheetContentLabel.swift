import UIKit
import Foundation_iOS

final class MessageSheetContentLabel: UILabel, MessageSheetContentProtocol {
    typealias ContentViewModel = String

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

    func bind(messageSheetContent: String?, locale _: Locale) {
        text = messageSheetContent
    }
}
