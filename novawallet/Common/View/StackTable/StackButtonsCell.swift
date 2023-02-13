import Foundation

final class StackButtonsCell: RowView<GenericPairValueView<TriangularedButton, TriangularedButton>> {
    var mainButton: TriangularedButton {
        rowContentView.sView
    }

    var secondaryButton: TriangularedButton {
        rowContentView.fView
    }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        rowContentView.makeHorizontal()
        rowContentView.spacing = 12
        rowContentView.stackView.distribution = .fillEqually

        mainButton.applyDefaultStyle()
        secondaryButton.applySecondaryDefaultStyle()
    }
}

extension StackButtonsCell: StackTableViewCellProtocol {}
