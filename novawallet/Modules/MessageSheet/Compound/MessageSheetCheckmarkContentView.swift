import UIKit
import Foundation_iOS

struct MessageSheetCheckmarkContentViewModel {
    let checked: Bool
    let text: LocalizableResource<String>
}

final class MessageSheetCheckmarkContentView: UIView, MessageSheetContentProtocol {
    typealias ContentViewModel = MessageSheetCheckmarkContentViewModel
    let controlView = CheckboxControlView()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(controlView)

        controlView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.centerX.equalToSuperview()
        }

        controlView.controlContentView.stackView.alignment = .center
    }

    func bind(messageSheetContent: ContentViewModel?, locale: Locale) {
        controlView.isChecked = messageSheetContent?.checked ?? false
        controlView.controlContentView.detailsLabel.text = messageSheetContent?.text.value(for: locale)
        controlView.controlContentView.detailsLabel.sizeToFit()
        controlView.setNeedsLayout()
    }
}
