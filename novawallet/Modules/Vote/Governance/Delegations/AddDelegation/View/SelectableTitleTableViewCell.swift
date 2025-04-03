import UIKit_iOS

final class SelectableTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    struct Model {
        let title: String
        let selected: Bool
    }

    var titleLabel: UILabel {
        view.titleView
    }

    var selectorView: RadioSelectorView {
        view.valueView
    }

    var checkmarked: Bool {
        get {
            selectorView.selected
        }

        set {
            selectorView.selected = newValue
        }
    }

    private let view = GenericTitleValueView<UILabel, RadioSelectorView>()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(view)

        let inset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(inset)
        }
        selectorView.snp.makeConstraints {
            $0.size.equalTo(2 * selectorView.outerRadius)
        }
    }

    func bind(model: Model) {
        view.titleView.text = model.title
        view.valueView.selected = model.selected
    }

    func applyStyle() {
        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellBackgroundPressed()
        self.selectedBackgroundView = selectedBackgroundView

        view.titleView.apply(style: .footnotePrimary)
    }
}
