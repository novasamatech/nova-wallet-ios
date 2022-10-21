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

    var proposerTableCell: StackInfoTableCell?
    let depositTableCell = StackTitleMultiValueCell()

    let approveCurve = StackTableCell()
    let supportCurve = StackTableCell()
    let callHash: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let jsonTitle: UILabel = .init(style: .rowTitle)
    let jsonView: BlurredView<UITextView> = .create {
        $0.view.allowsEditingTextAttributes = false
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        referendumDetailsTableView.addArrangedSubview(approveCurve)
        referendumDetailsTableView.addArrangedSubview(supportCurve)
        referendumDetailsTableView.addArrangedSubview(callHash)
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
        let model: StackCellViewModel?
    }
}

class BlurredView<TContentView>: UIView where TContentView: UIView {
    let view: TContentView = .init()
    let backgroundBlurView = TriangularedBlurView()

    var contentInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            updateLayout()
        }
    }

    var innerInsets: UIEdgeInsets = .zero {
        didSet {
            updateLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }

        backgroundBlurView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(innerInsets)
        }
    }

    private func updateLayout() {
        backgroundBlurView.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
        view.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(innerInsets)
        }
    }
}
