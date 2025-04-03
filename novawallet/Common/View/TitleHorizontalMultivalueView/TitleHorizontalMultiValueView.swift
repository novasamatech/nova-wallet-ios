import UIKit
import UIKit_iOS

class TitleHorizontalMultiValueView: GenericTitleValueView<UILabel, UIStackView> {
    let detailsTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        return label
    }()

    let detailsValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .regularFootnote
        return label
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    private func configureStyle() {
        titleView.textColor = R.color.colorTextSecondary()
        titleView.font = .regularFootnote

        valueView.spacing = 4.0
        valueView.addArrangedSubview(detailsTitleLabel)
        valueView.addArrangedSubview(detailsValueLabel)

        detailsTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
}

final class LoadableTitleHorizontalMultiValueView: TitleHorizontalMultiValueView {
    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }
}

extension LoadableTitleHorizontalMultiValueView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let size = CGSize(width: 57, height: 10)
        let offset = CGPoint(x: spaceSize.width - size.width, y: spaceSize.height / 2.0 - size.height / 2.0)

        let row = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: offset,
            size: size
        )

        return [row]
    }

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [valueView]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}
