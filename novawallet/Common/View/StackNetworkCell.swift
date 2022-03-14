import UIKit

class StackNetworkCell: RowView<GenericTitleValueView<UILabel, UIStackView>> {
    var titleLabel: UILabel { rowContentView.titleView }

    var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()!
        label.font = .regularFootnote
        return label
    }()

    var iconSize = CGSize(width: 20.0, height: 20.0) {
        didSet {
            if oldValue != iconSize {
                chainView.snp.updateConstraints { make in
                    make.size.equalTo(iconSize)
                }
            }
        }
    }

    var chainView: GradientIconView = {
        let view = GradientIconView()
        view.backgroundView.cornerRadius = 6.0
        return view
    }()

    private var viewModel: StackCellViewModel?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configureStyle()
    }

    func bind(viewModel: NetworkViewModel) {
        nameLabel.text = viewModel.name
        chainView.bind(iconViewModel: viewModel.icon, size: iconSize)
        chainView.bind(gradient: viewModel.gradient)
    }

    private func configureStyle() {
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .regularFootnote

        preferredHeight = 44.0
        borderView.strokeColor = R.color.colorWhite8()!

        isUserInteractionEnabled = false

        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        rowContentView.valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func setupLayout() {
        let stackView = rowContentView.valueView
        stackView.axis = .horizontal
        stackView.spacing = 8.0

        stackView.addArrangedSubview(chainView)
        stackView.addArrangedSubview(nameLabel)

        chainView.snp.makeConstraints { make in
            make.size.equalTo(iconSize)
        }
    }
}

extension StackNetworkCell: StackTableViewCellProtocol {}
