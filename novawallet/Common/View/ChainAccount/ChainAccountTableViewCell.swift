import UIKit

class ChainAccountTableViewCell: UITableViewCell {
    let chainAccountView = ChainAccountView()

    var contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 9.0, right: 16.0) {
        didSet {
            applyConstraints()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedAccent()
        self.selectedBackgroundView = selectedBackgroundView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(chainAccountView)
        applyConstraints()
    }

    private func applyConstraints() {
        chainAccountView.snp.remakeConstraints { make in
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
        }
    }
}
