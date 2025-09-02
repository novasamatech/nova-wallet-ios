import UIKit
import UIKit_iOS

@objc protocol DelegateInfoDelegate {
    func didTapOnDelegateInfo(sender: DelegateInfoView)
}

final class DelegateInfoView: UIView {
    typealias ContentView = GenericPairValueView<
        BorderedImageView,
        GenericPairValueView<
            GenericPairValueView<UILabel, GovernanceDelegateTypeView>,
            GenericPairValueView<UIImageView, UIView>
        >
    >

    let baseView = ContentView()

    weak var delegate: DelegateInfoDelegate? {
        didSet {
            baseView.isUserInteractionEnabled = delegate != nil
        }
    }

    var id: Int?

    var iconView: BorderedImageView {
        baseView.fView
    }

    var nameLabel: UILabel {
        baseView.sView.fView.fView
    }

    var typeView: GovernanceDelegateTypeView {
        baseView.sView.fView.sView
    }

    var indicatorView: UIImageView {
        baseView.sView.sView.fView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(baseView)
        baseView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        baseView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(didTapOnBaseView)
        ))

        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTapOnBaseView() {
        delegate?.didTapOnDelegateInfo(sender: self)
    }

    private func applyStyle() {
        backgroundColor = .clear

        baseView.makeHorizontal()
        baseView.spacing = Constants.nameIconSpace
        baseView.stackView.alignment = .center

        let detailsView = baseView.sView
        detailsView.spacing = Constants.space
        detailsView.fView.spacing = Constants.space
        detailsView.spacing = Constants.space
        detailsView.fView.makeHorizontal()
        detailsView.makeHorizontal()
        detailsView.fView.spacing = 4

        typeView.iconDetailsView.iconWidth = Constants.typeIconWidth
        typeView.contentInsets = Constants.typeIconInsets
        typeView.backgroundView.cornerRadius = 5

        nameLabel.numberOfLines = 1
        nameLabel.apply(style: .footnotePrimary)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)

        indicatorView.image = R.image.iconInfoFilled()
        typeView.setContentHuggingPriority(.required, for: .horizontal)
        detailsView.sView.sView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        detailsView.sView.sView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailsView.sView.makeHorizontal()
        detailsView.sView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}

extension DelegateInfoView {
    struct Model: Equatable {
        let type: GovernanceDelegateTypeView.Model?
        let addressViewModel: DisplayAddressViewModel

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.type == rhs.type && lhs.addressViewModel.address == rhs.addressViewModel.address &&
                lhs.addressViewModel.name == rhs.addressViewModel.name
        }
    }

    func bind(viewModel: Model) {
        bind(type: viewModel.type)

        iconView.bind(
            viewModel: viewModel.addressViewModel.imageViewModel,
            targetSize: Constants.iconSize,
            delegateType: viewModel.type
        )

        nameLabel.lineBreakMode = viewModel.addressViewModel.lineBreakMode
        nameLabel.text = viewModel.addressViewModel.name ?? viewModel.addressViewModel.address
        nameLabel.sizeToFit()
    }

    private func bind(type: GovernanceDelegateTypeView.Model?) {
        guard let type = type else {
            typeView.isHidden = true
            return
        }

        typeView.isHidden = false
        typeView.iconDetailsView.detailsLabel.isHidden = true
        switch type {
        case .individual:
            typeView.iconDetailsView.imageView.image = R.image.iconIndividual()
        case .organization:
            typeView.iconDetailsView.imageView.image = R.image.iconOrganization()
        }
    }

    private func iconRadius(for type: GovernanceDelegateTypeView.Model?) -> CGFloat? {
        switch type {
        case .organization:
            return nil
        case .individual, .none:
            return Constants.iconSize.width / 2
        }
    }
}

extension DelegateInfoView {
    enum Constants {
        static let nameIconSpace: CGFloat = 12
        static let iconSize = CGSize(width: 24, height: 24)
        static let space: CGFloat = 4
        static let indicatorWidth: CGFloat = 12
        static let typeIconWidth: CGFloat = 21
        static let typeIconInsets: UIEdgeInsets = .init(top: 1, left: 4, bottom: 1, right: 4)
    }
}
