import UIKit

final class VotesTableViewCell: UITableViewCell {
    enum Constants {
        static let rowHeight: CGFloat = 44.0
        static let addressIndicatorSpacing: CGFloat = 4.0
        static let addressNameSpacing: CGFloat = 12.0
    }

    let baseView = VotesContentView(frame: .zero)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: VotesViewModel) {
        baseView.bind(viewModel: viewModel)
        setNeedsLayout()
    }

    private func applyStyle() {
        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellBackgroundPressed()
        self.selectedBackgroundView = selectedBackgroundView
    }

    private func setupLayout() {
        contentView.addSubview(baseView)

        baseView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }
}
