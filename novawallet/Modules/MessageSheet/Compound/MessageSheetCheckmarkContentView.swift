import UIKit

struct MessageSheetCheckmarkContentViewModel {
    let checked: Bool
    let text: String
}

final class MessageSheetCheckmarkContentView: UIView, MessageSheetContentProtocol {
    typealias ContentViewModel = MessageSheetCheckmarkContentViewModel
    let controlView = CheckboxControlView()
    
    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 40)
    }

    func bind(messageSheetContent: ContentViewModel?, locale: Locale) {
        controlView.isChecked = messageSheetContent?.checked ?? false
        controlView.controlContentView.detailsLabel.text = messageSheetContent?.text
    }
}
