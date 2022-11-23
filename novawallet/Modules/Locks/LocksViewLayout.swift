import UIKit

final class LocksViewLayout: GenericCollectionViewLayout<GenericTitleValueView<UILabel, UILabel>> {
    let titleLabel: UILabel = .create {
        $0.font = .semiBoldBody
        $0.textColor = R.color.colorTextPrimary()
    }

    let valueLabel: UILabel = .create {
        $0.font = .regularSubheadline
        $0.textColor = R.color.colorTextPrimary()
    }

    override init(frame _: CGRect = .zero) {
        let settings = GenericCollectionViewLayoutSettings(
            pinToVisibleBounds: false,
            estimatedRowHeight: 44,
            absoluteHeaderHeight: 48
        )
        super.init(header: .init(titleView: titleLabel, valueView: valueLabel), settings: settings)
    }
}
