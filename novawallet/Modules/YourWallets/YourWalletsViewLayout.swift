import UIKit

final class YourWalletsViewLayout: GenericCollectionViewLayout<UILabel> {
    let titleLabel: UILabel = .create {
        $0.font = .semiBoldBody
        $0.textColor = R.color.colorWhite()
    }

    override init(frame _: CGRect = .zero) {
        super.init(header: titleLabel)
    }
}
