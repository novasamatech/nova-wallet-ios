import UIKit

typealias MessageSheetNoContentViewModel = ()

final class MessageSheetNoContentView: UIView, MessageSheetContentProtocol {
    typealias ContentViewModel = MessageSheetNoContentViewModel

    override var intrinsicContentSize: CGSize {
        CGSize.zero
    }

    func bind(messageSheetContent _: ContentViewModel?, locale _: Locale) {}
}
