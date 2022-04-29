import Foundation
import UIKit

final class StackTitleMultiValueCell: RowView<GenericTitleValueView<IconDetailsView, MultiValueView>> {
    var titleLabel: UILabel { rowContentView.titleView.detailsLabel }
    var topValueLabel: UILabel { rowContentView.valueView.valueTop }
    var bottomValueLabel: UILabel { rowContentView.valueView.valueBottom }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    var canSelect: Bool = true {
        didSet {
            if oldValue != canSelect {
                updateSelection()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateSelection() {
        if canSelect {
            isUserInteractionEnabled = true
            rowContentView.titleView.imageView.image = R.image.iconInfoFilled()?.tinted(
                with: R.color.colorTransparentText()!
            )
        } else {
            isUserInteractionEnabled = false
            rowContentView.titleView.imageView.image = nil
        }
    }

    private func configure() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .regularFootnote

        rowContentView.titleView.mode = .detailsIcon
        rowContentView.titleView.spacing = 4.0

        topValueLabel.textColor = R.color.colorWhite()
        topValueLabel.font = .regularFootnote
        bottomValueLabel.textColor = R.color.colorTransparentText()
        bottomValueLabel.font = .caption1

        borderView.strokeColor = R.color.colorWhite8()!

        updateSelection()
    }
}

extension StackTitleMultiValueCell: StackTableViewCellProtocol {}
