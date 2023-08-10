import UIKit

final class ParagraphView: RowView<IconDetailsView> {
    var imageView: UIImageView { rowContentView.imageView }
    var detailsLabel: UILabel { rowContentView.detailsLabel }
    var style: Style = .defaultStyle

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        rowContentView.stackView.alignment = .top
        rowContentView.iconWidth = 32
        rowContentView.spacing = 16
        isUserInteractionEnabled = false
    }
}

extension ParagraphView {
    struct Model {
        let image: UIImage?
        let text: AccentTextModel
    }

    typealias Style = MultiColorTextStyle

    func bind(viewModel: Model) {
        imageView.image = viewModel.image
        detailsLabel.bind(
            model: viewModel.text,
            with: style
        )
    }
}

extension ParagraphView.Style {
    static let defaultStyle = ParagraphView.Style(
        textColor: R.color.colorTextPrimary()!,
        accentTextColor: R.color.colorPolkadotBrand()!,
        font: .semiBoldTitle3
    )

    static func createParagraphStyle(for themeColor: UIColor) -> ParagraphView.Style {
        ParagraphView.Style(
            textColor: R.color.colorTextPrimary()!,
            accentTextColor: themeColor,
            font: .semiBoldTitle3
        )
    }

    static func createHeaderStyle(for themeColor: UIColor) -> ParagraphView.Style {
        ParagraphView.Style(
            textColor: R.color.colorTextPrimary()!,
            accentTextColor: themeColor,
            font: .boldTitle1
        )
    }
}
