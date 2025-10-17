import UIKit
import Foundation_iOS

final class TransferConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let amountView = MultilineBalanceView()

    let senderTableView = StackTableView()

    let originNetworkCell = StackNetworkCell()

    private(set) var destinationNetworkCell: StackNetworkCell?

    let walletCell = StackTableCell()
    let senderCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let recepientTableView = StackTableView()

    let recepientCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let originFeeCell = StackNetworkFeeCell()

    private(set) var crossChainFeeCell: StackNetworkFeeCell?
    private(set) var crossChainHintView: HintListView?

    let actionLoadableView = LoadableActionView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func switchCrossChain() {
        if destinationNetworkCell == nil {
            let destinationNetworkCell = StackNetworkCell()

            recepientTableView.insertArrangedSubview(destinationNetworkCell, at: 0)

            self.destinationNetworkCell = destinationNetworkCell
        }

        if crossChainFeeCell == nil {
            let crossChainFeeCell = StackNetworkFeeCell()
            crossChainFeeCell.rowContentView.title = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonCrossChainFee()
            }

            senderTableView.addArrangedSubview(crossChainFeeCell)

            self.crossChainFeeCell = crossChainFeeCell
        }

        if crossChainHintView == nil {
            let crossChainHintView = HintListView()

            containerView.stackView.insertArranged(view: crossChainHintView, after: senderTableView)

            containerView.stackView.setCustomSpacing(12.0, after: crossChainHintView)

            self.crossChainHintView = crossChainHintView
        }

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionLoadableView.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.setCustomSpacing(20.0, after: amountView)

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

        senderTableView.addArrangedSubview(originNetworkCell)
        senderTableView.addArrangedSubview(walletCell)
        senderTableView.addArrangedSubview(senderCell)
        senderTableView.addArrangedSubview(originFeeCell)

        containerView.stackView.addArrangedSubview(recepientTableView)
        recepientTableView.addArrangedSubview(recepientCell)
    }
}
