import UIKit
import SoraUI

class MultiValueView: GenericMultiValueView<UILabel> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        valueBottom.textColor = R.color.colorGray()
        valueBottom.font = .p2Paragraph
        valueBottom.textAlignment = .right
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = max(valueTop.intrinsicContentSize.width, valueBottom.intrinsicContentSize.width)
        return size
    }

    func bind(topValue: String, bottomValue: String?) {
        valueTop.text = topValue

        if let bottomValue = bottomValue {
            valueBottom.isHidden = false
            valueBottom.text = bottomValue
        } else {
            valueBottom.text = ""
            valueBottom.isHidden = true
        }
    }
}
