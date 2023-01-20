import SoraUI

final class SelectableTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    struct Model {
        let title: String
        let selected: Bool
    }

    let view = GenericTitleValueView<UILabel, RadioSelectorView>()
    var checkmarked: Bool = false

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

        view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(model: Model) {
        view.titleView.text = model.title
        view.valueView.selected = model.selected
    }

    func applyStyle() {
        view.titleView.apply(style: .footnotePrimary)
    }
}
