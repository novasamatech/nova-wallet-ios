import UIKit
import UIKit_iOS
import SnapKit

class ExportRowView: GenericPairValueView<
    GenericPairValueView<
        UILabel,
        UILabel
    >,
    GenericBackgroundView<MultiValueView>
> {
    private var titleHStack: GenericPairValueView<UILabel, UILabel> { fView }
    private var contentLabels: MultiValueView { sView.wrappedView }
    var blockView: GenericBackgroundView<MultiValueView> { sView }
    var leftTitle: UILabel { fView.fView }
    var rightTitle: UILabel { fView.sView }
    var mainContentLabel: UILabel { contentLabels.valueTop }
    var secondaryContentLabel: UILabel { contentLabels.valueBottom }

    var coverView: UIView?

    var type: RowType = .none

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    func setContentSingleLabel() {
        mainContentLabel.apply(style: .regularSubhedlineSecondary)
        mainContentLabel.numberOfLines = 0
        secondaryContentLabel.isHidden = true
        blockView.contentInsets = Constants.singleLabelContentInset
    }

    func setContentStackedLabels() {
        mainContentLabel.apply(style: .footnoteSecondary)
        mainContentLabel.numberOfLines = 1
        secondaryContentLabel.apply(style: .caption1Secondary)
        secondaryContentLabel.numberOfLines = 1
        secondaryContentLabel.isHidden = false
        blockView.contentInsets = Constants.stackedLabelContentInset
    }

    func setHiddenContent() {
        guard let coverView else { return }

        blockView.addSubview(coverView)

        coverView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setShowingContent() {
        coverView?.removeFromSuperview()
    }

    func setupButtonStyle() {
        mainContentLabel.apply(style: .semiboldSubheadlineAccent)
        mainContentLabel.numberOfLines = 1
        mainContentLabel.textAlignment = .center
        secondaryContentLabel.isHidden = true
        blockView.contentInsets = Constants.singleLabelContentInset
    }
}

extension ExportRowView {
    enum RowType: Hashable {
        case none
        case chainSecret(chainName: String)
    }
}

// MARK: Private

private extension ExportRowView {
    func setupLayout() {
        spacing = Constants.titleBlockSpacing
        contentLabels.spacing = Constants.contentLabelsSpacing

        titleHStack.makeHorizontal()
        titleHStack.stackView.distribution = .fillEqually
    }

    func setupStyle() {
        leftTitle.apply(style: .footnoteSecondary)
        rightTitle.apply(style: .footnoteSecondary)

        leftTitle.textAlignment = .left
        rightTitle.textAlignment = .right

        mainContentLabel.textAlignment = .left
        secondaryContentLabel.textAlignment = .left

        setContentSingleLabel()

        blockView.cornerRadius = Constants.cornerRadius
        blockView.roundingCorners = .allCorners
        blockView.fillColor = R.color.colorBlockBackground()!
    }
}

// MARK: Constants

private extension ExportRowView {
    enum Constants {
        static let titleBlockSpacing: CGFloat = 8
        static let contentLabelsSpacing: CGFloat = 4
        static let cornerRadius: CGFloat = 12
        static let singleLabelContentInset: UIEdgeInsets = .init(
            top: 14,
            left: 12,
            bottom: 14,
            right: 12
        )
        static let stackedLabelContentInset: UIEdgeInsets = .init(
            top: 9,
            left: 12,
            bottom: 9,
            right: 12
        )
    }
}
