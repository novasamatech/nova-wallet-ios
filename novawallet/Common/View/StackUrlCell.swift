import UIKit
import SoraUI

final class StackUrlCell: RoundedView {
    private let contentView = GenericTitleValueView<UILabel, RoundedButton>()

    var titleLabel: UILabel { contentView.titleView }
    var actionButton: RoundedButton { contentView.valueView }

    var contentInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0) {
        didSet {
            borderView.snp.updateConstraints { make in
                make.leading.equalToSuperview().inset(contentInsets.left)
                make.trailing.equalToSuperview().inset(contentInsets.right)
            }
        }
    }

    var cellHeight: CGFloat = 44.0 {
        didSet {
            borderView.snp.updateConstraints { make in
                make.height.equalTo(cellHeight)
            }
        }
    }

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.strokeWidth = UIConstants.separatorHeight
        view.strokeColor = R.color.colorWhite8()!
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configureStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(cellHeight)
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(borderView)
        }
    }

    private func configureStyle() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .regularFootnote

        actionButton.applyIconStyle()
        actionButton.imageWithTitleView?.titleColor = R.color.colorNovaBlue()!
        actionButton.imageWithTitleView?.titleFont = .regularFootnote
        actionButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        actionButton.contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)

        applyFilledBackgroundStyle()
        fillColor = .clear
    }
}

extension StackUrlCell: StackTableViewCellProtocol {
    var preferredHeight: CGFloat? {
        get {
            cellHeight
        }
        set {
            cellHeight = newValue ?? 44.0
        }
    }

    var roundedBackgroundView: RoundedView! {
        self
    }
}
