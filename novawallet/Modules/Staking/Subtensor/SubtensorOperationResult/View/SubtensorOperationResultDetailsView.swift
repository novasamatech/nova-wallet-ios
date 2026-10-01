import UIKit

final class SubtensorOperationResultDetailsView: CollapsableContainerView {
    let swapRateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 12
        $0.roundedBackgroundView.roundingCorners = [.topLeft, .topRight]
    }

    let costBasisCell: SwapNetworkFeeViewCell = .create {
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 0
        $0.rowContentView.valueView.stackView.alignment = .trailing
        $0.valueTopButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 3
    }

    let slippageCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 0
    }

    let validatorCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .bottom
        $0.roundedBackgroundView.cornerRadius = 0
    }

    let networkFeeCell: SwapNetworkFeeViewCell = .create {
        $0.contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        $0.borderView.borderType = .none
        $0.roundedBackgroundView.cornerRadius = 12
        $0.roundedBackgroundView.roundingCorners = [.bottomLeft, .bottomRight]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundView.sideLength = 12
    }

    override var rows: [UIView] {
        [swapRateCell, costBasisCell, slippageCell, validatorCell, networkFeeCell]
    }

    func setup(locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        swapRateCell.titleButton.setTitle(strings.stakingSubtensorUiSwapRate())
        slippageCell.titleButton.setTitle(strings.swapsSetupSlippage())
        validatorCell.titleButton.setTitle(strings.stakingCommonValidator())
        networkFeeCell.titleButton.setTitle(strings.commonNetworkFee())
    }

    func bind(viewModel: SubtensorResultDetailsViewModel) {
        titleControl.titleLabel.text = viewModel.title

        swapRateCell.bind(loadableViewModel: .loaded(value: viewModel.swapRate))
        validatorCell.bind(loadableViewModel: .loaded(value: viewModel.validator))

        costBasisCell.titleButton.setTitle(viewModel.costBasis?.title)
        costBasisCell.bind(costBasisRow: viewModel.costBasis?.value ?? .hidden)

        slippageCell.isHidden = viewModel.slippage == nil

        if let slippage = viewModel.slippage {
            slippageCell.bind(loadableViewModel: .loaded(value: slippage))
        }

        networkFeeCell.isHidden = viewModel.networkFee == nil
        validatorCell.borderView.borderType = viewModel.networkFee == nil ? .none : .bottom

        if let networkFee = viewModel.networkFee {
            let feeViewModel = NetworkFeeInfoViewModel(isEditable: false, balanceViewModel: networkFee)
            networkFeeCell.bind(loadableViewModel: .loaded(value: feeViewModel))
        }
    }
}
