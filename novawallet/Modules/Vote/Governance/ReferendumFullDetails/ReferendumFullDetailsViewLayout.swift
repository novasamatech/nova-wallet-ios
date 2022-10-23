import UIKit

final class ReferendumFullDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let accountDetailsTableView = StackTableView()
    var referendumDetailsTableView = StackTableView()
    var amountSpendDetailsTableView: AmountSpendDetailsTableView?
    lazy var beneficiaryTableCell = StackInfoTableCell()
    lazy var requestedAmountTableCell = StackTitleMultiValueCell()

    var proposerTableCell: StackInfoTableCell?
    let depositTableCell = StackTitleMultiValueCell()

    var approveCurve: StackTableCell?
    var supportCurve: StackTableCell?
    var callHash: StackInfoTableCell?

    let jsonTitle: UILabel = .init(style: .caption1White64)
    let jsonView: BlurredView<UITextView> = .create {
        $0.view.allowsEditingTextAttributes = false
        $0.view.isScrollEnabled = false
        $0.view.backgroundColor = .clear
        $0.view.textAlignment = .left
        $0.contentInsets = .zero
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.stackView.spacing = 8
        containerView.stackView.addArrangedSubview(accountDetailsTableView)
        containerView.stackView.addArrangedSubview(referendumDetailsTableView)
        accountDetailsTableView.addArrangedSubview(depositTableCell)
        containerView.stackView.addArrangedSubview(jsonTitle)
        containerView.stackView.addArrangedSubview(jsonView)
    }

    func updateProposerCell(proposerModel: ProposerTableCell.Model?) {
        guard let proposerModel = proposerModel else {
            proposerTableCell?.removeFromSuperview()
            proposerTableCell = nil
            return
        }
        if proposerTableCell == nil {
            let proposerTableCell = createStackInfoCell(title: proposerModel.title)
            accountDetailsTableView.insertArrangedSubview(proposerTableCell, at: 0)
            self.proposerTableCell = proposerTableCell
        }

        proposerTableCell?.bind(viewModel: proposerModel.model)
    }

    func update(amountSpendDetails: AmountSpendDetailsTableView.Model?) {
        guard let amountSpendDetails = amountSpendDetails else {
            amountSpendDetailsTableView?.removeFromSuperview()
            amountSpendDetailsTableView = nil
            return
        }
        if amountSpendDetailsTableView == nil {
            amountSpendDetailsTableView = .init()
            accountDetailsTableView.addArrangedSubview(beneficiaryTableCell)
            accountDetailsTableView.addArrangedSubview(requestedAmountTableCell)
        }
        beneficiaryTableCell.titleLabel.text = amountSpendDetails.beneficiary.title
        beneficiaryTableCell.bind(viewModel: amountSpendDetails.beneficiary.model)
        requestedAmountTableCell.titleLabel.text = amountSpendDetails.requestedAmount.title
        requestedAmountTableCell.rowContentView.valueView.bind(viewModel: amountSpendDetails.requestedAmount.model)
    }

    func update(approveCurveModel: TitleWithSubtitleViewModel?) {
        guard let model = approveCurveModel else {
            approveCurve?.removeFromSuperview()
            approveCurve = nil
            return
        }
        if approveCurve == nil {
            approveCurve = .init()
            approveCurve.map(referendumDetailsTableView.addArrangedSubview)
        }
        approveCurve?.titleLabel.text = model.title
        approveCurve?.detailsLabel.text = model.subtitle
    }

    func update(supportCurveModel: TitleWithSubtitleViewModel?) {
        guard let model = supportCurveModel else {
            supportCurve?.removeFromSuperview()
            supportCurve = nil
            return
        }
        if supportCurve == nil {
            supportCurve = .init()
            supportCurve.map(referendumDetailsTableView.addArrangedSubview)
        }
        supportCurve?.titleLabel.text = model.title
        supportCurve?.detailsLabel.text = model.subtitle
    }

    func update(callHashModel: TitleWithSubtitleViewModel?) {
        guard let model = callHashModel else {
            callHash?.removeFromSuperview()
            callHash = nil
            return
        }
        if callHash == nil {
            callHash = .init()
            callHash.map(referendumDetailsTableView.addArrangedSubview)
        }
        callHash?.titleLabel.text = model.title
        callHash?.detailsLabel.text = model.subtitle
    }

    private func createStackInfoCell(title: String) -> StackInfoTableCell {
        let proposerCell = StackInfoTableCell()
        proposerCell.rowContentView.valueView.mode = .iconDetails
        proposerCell.rowContentView.titleView.text = title
        return proposerCell
    }
}

typealias ProposerTableCell = StackInfoTableCell
extension ProposerTableCell {
    struct Model {
        let title: String
        let model: StackCellViewModel?
    }
}

typealias AmountSpendDetailsTableView = StackTableView
extension AmountSpendDetailsTableView {
    struct Model {
        let beneficiary: BeneficiaryModel
        let requestedAmount: RequestedAmountModel
    }

    struct BeneficiaryModel {
        let title: String
        let model: StackCellViewModel?
    }

    struct RequestedAmountModel {
        let title: String
        let model: MultiValueView.Model
    }
}
