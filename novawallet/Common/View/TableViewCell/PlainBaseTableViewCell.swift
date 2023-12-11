import UIKit

class PlainBaseTableViewCell<C: UIView>: UITableViewCell {
    let contentDisplayView = C()

    var contentInsets = UIEdgeInsets(
        top: 0,
        left: UIConstants.horizontalInset,
        bottom: 0,
        right: UIConstants.horizontalInset
    ) {
        didSet {
            if oldValue != contentInsets {
                updateLayout()
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupStyle() {
        let selectionView = UIView()
        selectionView.backgroundColor = R.color.colorCellBackgroundPressed()

        selectedBackgroundView = selectionView
    }

    func setupLayout() {
        contentView.addSubview(contentDisplayView)

        contentDisplayView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func updateLayout() {
        contentDisplayView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
