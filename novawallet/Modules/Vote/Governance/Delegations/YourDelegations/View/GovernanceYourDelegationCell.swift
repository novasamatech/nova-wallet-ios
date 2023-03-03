import UIKit

typealias GovernanceYourDelegationCellView = GenericPairValueView<GovernanceDelegateView, GovernanceDelegationCellView>
final class GovernanceYourDelegationCell: BlurredTableViewCell<GovernanceYourDelegationCellView> {
    private enum Constants {
        static let footerHeight: CGFloat = 57
    }

    var delegateView: GovernanceDelegateView {
        view.fView
    }

    var delegationView: GovernanceDelegationCellView {
        view.sView
    }

    let footerBlurView = BlockBackgroundView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        applyStyle()
    }

    private func setupLayout() {
        backgroundBlurView.addSubview(footerBlurView)
        footerBlurView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Constants.footerHeight)
        }

        delegationView.snp.makeConstraints { make in
            make.height.equalTo(Constants.footerHeight)
        }

        view.spacing = 16
    }

    private func applyStyle() {
        shouldApplyHighlighting = true
        contentInsets = .init(top: 4, left: 16, bottom: 4, right: 16)
        innerInsets = .init(top: 12, left: 12, bottom: 0, right: 12)
        backgroundBlurView.sideLength = 12
        footerBlurView.sideLength = 12
        footerBlurView.cornerCut = [.bottomLeft, .bottomRight]
    }

    func bind(viewModel: Model, locale: Locale) {
        delegateView.bind(viewModel: viewModel.delegateViewModel, locale: locale)
        delegationView.bind(viewModel: viewModel.delegationViewModel)
    }
}

extension GovernanceYourDelegationCell {
    struct Model: Hashable {
        var identifier: AccountAddress { delegateViewModel.addressViewModel.address }

        let delegateViewModel: GovernanceDelegateTableViewCell.Model
        let delegationViewModel: GovernanceDelegationCellView.Model
    }
}
