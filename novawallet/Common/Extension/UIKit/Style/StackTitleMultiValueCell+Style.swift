import UIKit

extension StackTitleMultiValueCell {
    struct Style {
        let title: IconDetailsView.Style
        let value: MultiValueView.Style
    }

    func apply(style: Style) {
        rowContentView.titleView.apply(style: style.title)
        rowContentView.valueView.apply(style: style.value)
    }
}
