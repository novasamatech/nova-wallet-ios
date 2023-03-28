import UIKit

final class SelectableAddressTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    struct Model {
        let address: DisplayAddressViewModel
        let selected: Bool
    }

    var identityView: IdentityAccountInfoView {
        view.fView
    }

    var selectorView: RadioSelectorView {
        view.sView
    }

    var checkmarked: Bool {
        get {
            selectorView.selected
        }

        set {
            selectorView.selected = newValue
        }
    }

    private let view = GenericPairValueView<IdentityAccountInfoView, RadioSelectorView>()

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

        let insets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(insets)
        }

        selectorView.snp.makeConstraints {
            $0.size.equalTo(2 * selectorView.outerRadius)
        }

        identityView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        identityView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        identityView.actionIcon = nil
        identityView.isUserInteractionEnabled = false
        identityView.roundedBackgroundView.roundingCorners = []
        identityView.roundedBackgroundView.applyFilledBackgroundStyle()
        identityView.roundedBackgroundView.fillColor = .clear
        identityView.roundedBackgroundView.highlightedFillColor = .clear

        view.setHorizontalAndSpacing(8)
    }

    func bind(model: Model) {
        identityView.bind(viewModel: model.address)
        selectorView.selected = model.selected
        identityView.invalidateIntrinsicContentSize()
    }

    func applyStyle() {
        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellBackgroundPressed()
        self.selectedBackgroundView = selectedBackgroundView
    }
}
