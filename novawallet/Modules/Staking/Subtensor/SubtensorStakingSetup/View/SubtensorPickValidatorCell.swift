import UIKit

final class SubtensorPickValidatorCell: StackInfoTableCell {
    private let loadingView = SubtensorChartLoadingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        detailsLabel.numberOfLines = 2
        detailsLabel.textAlignment = .right
        addSubview(loadingView)
        loadingView.snp
            .makeConstraints { $0.trailing.centerY.equalToSuperview(); $0.width.equalTo(90); $0.height.equalTo(10) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(validator: SubtensorSetupValidatorViewModel, rate: String?, isEditable: Bool) {
        canSelect = isEditable && !validator.isLoading
        loadingView.setLoading(validator.isLoading)
        switch validator {
        case .loading: bind(viewModel: nil)
        case let .unselected(title): bind(details: title)
        case let .selected(address, _):
            bind(viewModel: StackCellViewModel(
                details: address.name ?? address.address,
                imageViewModel: address.imageViewModel
            ))
            if let rate {
                let text = NSMutableAttributedString(string: address.name ?? address.address)
                text.append(NSAttributedString(string: "\n" + rate, attributes: [
                    .font: UIFont.caption1, .foregroundColor: R.color.colorTextPositive()!
                ]))
                detailsLabel.attributedText = text
            }
        }
        if canSelect { accessoryImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        }
    }
}
