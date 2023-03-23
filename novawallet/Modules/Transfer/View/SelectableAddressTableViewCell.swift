import UIKit

final class SelectableAddressTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    struct Model {
        let address: DisplayAddressViewModel
        let selected: Bool
    }

    var identityView: IdentityAccountInfoView {
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

    private let view = GenericTitleValueView<IdentityAccountInfoView, RadioSelectorView>()

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

        let inset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(inset)
        }

        selectorView.snp.makeConstraints {
            $0.size.equalTo(2 * selectorView.outerRadius)
        }
    }

    func bind(model: Model) {
        identityView.bind(viewModel: model.address)
        selectorView.selected = model.selected
    }

    func applyStyle() {
        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellBackgroundPressed()
        self.selectedBackgroundView = selectedBackgroundView
    }
}
