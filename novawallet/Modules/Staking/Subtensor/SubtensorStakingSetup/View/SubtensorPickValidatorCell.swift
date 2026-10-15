import UIKit

final class SubtensorPickValidatorCell: RowView<
    GenericTitleValueView<UILabel, GenericPairValueView<SubtensorValidatorDetailsValueView, UIImageView>>
>, StackTableViewCellProtocol {
    var titleLabel: UILabel { rowContentView.titleView }

    private var validatorView: SubtensorValidatorDetailsValueView { rowContentView.valueView.fView }
    private var accessoryImageView: UIImageView { rowContentView.valueView.sView }

    private let loadingView = SubtensorSkeletonView()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(validator: SubtensorSetupValidatorViewModel, rate: String?, isEditable: Bool) {
        let canSelect = isEditable && !validator.isLoading
        isUserInteractionEnabled = canSelect
        accessoryImageView.isHidden = !canSelect
        loadingView.setLoading(validator.isLoading)

        switch validator {
        case .loading:
            validatorView.bind(title: nil)
            validatorView.bind(apy: nil)
        case let .unselected(title):
            validatorView.bind(title: title)
            validatorView.bind(apy: nil)
        case let .selected(address):
            validatorView.bind(viewModel: address)
            validatorView.bind(apy: rate)
        }
    }
}

private extension SubtensorPickValidatorCell {
    enum Constants {
        static let height: CGFloat = 44
        static let accessorySize: CGFloat = 16
        static let accessorySpacing: CGFloat = 8
        static let loadingSize = CGSize(width: 90, height: 10)
    }

    func setupLayout() {
        preferredHeight = Constants.height

        titleLabel.apply(style: .footnoteSecondary)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let valueView = rowContentView.valueView
        valueView.setHorizontalAndSpacing(Constants.accessorySpacing)
        valueView.stackView.alignment = .center
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        accessoryImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        accessoryImageView.contentMode = .scaleAspectFit
        accessoryImageView.snp.makeConstraints { $0.size.equalTo(Constants.accessorySize) }

        addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(Constants.loadingSize)
        }
    }
}
