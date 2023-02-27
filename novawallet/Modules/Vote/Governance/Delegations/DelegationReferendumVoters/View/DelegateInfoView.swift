import UIKit
import SoraUI

@objc protocol DelegateInfoDelegate {
    func didTapOnDelegateInfo(sender: DelegateInfoView)
}

final class DelegateInfoView: UIView {
    typealias ContentView = IconDetailsGenericView<GenericPairValueView<
        GenericPairValueView<UILabel, GovernanceDelegateTypeView>, UIImageView
    >>

    let baseView = ContentView()
    private var viewModel: Model?
    weak var delegate: DelegateInfoDelegate?
    var id: Int?

    var iconView: UIImageView {
        baseView.imageView
    }

    var nameLabel: UILabel {
        baseView.detailsView.fView.fView
    }

    var typeView: GovernanceDelegateTypeView {
        baseView.detailsView.fView.sView
    }

    var indicatorView: UIImageView {
        baseView.detailsView.sView
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
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTapOnBaseView(_: Any?) {
        delegate?.didTapOnDelegateInfo(sender: self)
    }

    private func applyStyle() {
        backgroundColor = .clear

        baseView.spacing = Constants.nameIconSpace
        baseView.mode = .iconDetails
        baseView.iconWidth = Constants.iconSize.width

        baseView.detailsView.fView.spacing = Constants.nameTypeSpace
        baseView.detailsView.fView.sView.iconDetailsView.iconWidth = Constants.typeIconWidth
        baseView.detailsView.fView.makeHorizontal()
        baseView.detailsView.makeHorizontal()
        baseView.detailsView.fView.sView.contentInsets = .init(top: 1, left: 4, bottom: 1, right: 6)
        baseView.detailsView.fView.sView.backgroundView.cornerRadius = 5

        nameLabel.numberOfLines = 1
        nameLabel.apply(style: .footnotePrimary)
        indicatorView.image = R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!)
    }
}

extension DelegateInfoView {
    struct Model {
        let type: GovernanceDelegateTypeView.Model?
        let addressViewModel: DisplayAddressViewModel
    }

    func bind(viewModel: Model) {
        bind(type: viewModel.type)

        self.viewModel?.addressViewModel.imageViewModel?.cancel(on: iconView)

        if let iconRadius = iconRadius(for: viewModel.type) {
            viewModel.addressViewModel.imageViewModel?.loadImage(
                on: iconView,
                targetSize: Constants.iconSize,
                cornerRadius: iconRadius,
                animated: true
            )
        } else {
            viewModel.addressViewModel.imageViewModel?.loadImage(
                on: iconView,
                targetSize: Constants.iconSize,
                animated: true
            )
        }

        nameLabel.lineBreakMode = viewModel.addressViewModel.lineBreakMode
        nameLabel.text = viewModel.addressViewModel.name ?? viewModel.addressViewModel.address
        self.viewModel = viewModel
    }

    private func bind(type: GovernanceDelegateTypeView.Model?) {
        guard let type = type else {
            typeView.isHidden = true
            return
        }

        typeView.isHidden = false
        switch type {
        case .individual:
            typeView.iconDetailsView.bind(viewModel: .init(
                title: "",
                icon: R.image.iconIndividual()
            ))
        case .organization:
            typeView.iconDetailsView.bind(viewModel: .init(
                title: "",
                icon: R.image.iconOrganization()
            ))
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
        static let nameTypeSpace: CGFloat = 4
        static let indicatorWidth: CGFloat = 12
        static let typeIconWidth: CGFloat = 21
    }
}
