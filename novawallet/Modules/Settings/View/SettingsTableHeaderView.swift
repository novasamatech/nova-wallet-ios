import UIKit

final class SettingsTableHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let accountDetailsView: DetailsTriangularedView = {
        let detailsView = UIFactory().createDetailsView(with: .singleTitle, filled: false)
        detailsView.titleLabel.lineBreakMode = .byTruncatingMiddle
        detailsView.titleLabel.font = .p1Paragraph
        detailsView.actionImage = R.image.iconMore()
        detailsView.highlightedFillColor = R.color.colorHighlightedAccent()!
        detailsView.strokeColor = R.color.colorStrokeGray()!
        detailsView.borderWidth = 1
        return detailsView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.vStack(spacing: 16, [.hStack([titleLabel, UIView()]), accountDetailsView])
        accountDetailsView.snp.makeConstraints { $0.height.equalTo(52) }

        addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(1)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }
    }
}
