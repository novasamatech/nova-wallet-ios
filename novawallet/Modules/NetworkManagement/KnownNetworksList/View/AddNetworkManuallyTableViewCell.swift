import UIKit
import UIKit_iOS

class AddNetworkManuallyTableViewCell: PlainBaseTableViewCell<
    GenericPairValueView<
        UIImageView,
        UILabel
    >
> {
    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
        contentDisplayView.sView.apply(style: .semiboldFootnoteAccentText)
    }

    override func setupLayout() {
        super.setupLayout()

        contentDisplayView.makeHorizontal()
        contentDisplayView.spacing = 12

        contentDisplayView.fView.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }
    }

    func bind(model: IconWithTitleViewModel) {
        contentDisplayView.fView.image = model.icon
        contentDisplayView.fView.contentMode = .scaleAspectFit
        contentDisplayView.sView.text = model.title
    }
}
