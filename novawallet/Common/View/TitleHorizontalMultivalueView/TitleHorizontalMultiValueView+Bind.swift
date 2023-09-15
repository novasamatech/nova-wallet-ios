import UIKit

extension TitleHorizontalMultiValueView {
    struct Model {
        let title: String
        let subtitle: String
        let value: String
    }

    func bind(model: Model) {
        titleView.text = model.title
        detailsTitleLabel.text = model.subtitle
        detailsValueLabel.text = model.value
    }
}
