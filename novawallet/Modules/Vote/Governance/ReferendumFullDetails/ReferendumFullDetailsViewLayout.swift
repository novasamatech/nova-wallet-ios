import UIKit
import SoraUI

final class ReferendumFullDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    private(set) var proposerTableView: StackTableView?
    private(set) var beneficiaryTableView: StackTableView?
    private(set) var curveAndHashTableView: StackTableView?

    private(set) var proposerCell: StackInfoTableCell?
    private(set) var beneficiaryCell: StackInfoTableCell?
    private(set) var callHashCell: StackInfoTableCell?

    private(set) var jsonView: UIView?

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
    }

    func setProposer(viewModel: ReferendumFullDetailsViewModel.Proposer?, locale: Locale) {
        proposerTableView?.clear()
        proposerCell = nil

        if let viewModel = viewModel {
            if proposerTableView == nil {
                let tableView = StackTableView()
                containerView.stackView.insertArrangedSubview(tableView, at: 0)
                proposerTableView = tableView
            }

            let proposerCell = createAccountCell(
                with: R.string.localizable.govProposer(preferredLanguages: locale.rLanguages),
                viewModel: viewModel.proposer
            )

            self.proposerCell = proposerCell

            proposerTableView?.addArrangedSubview(proposerCell)

            if let deposit = viewModel.deposit {
                let depositCell = createBalanceCell(
                    with: R.string.localizable.govDeposit(preferredLanguages: locale.rLanguages),
                    viewModel: deposit
                )
                proposerTableView?.addArrangedSubview(depositCell)
            }
        } else {
            proposerTableView?.removeFromSuperview()
            proposerTableView = nil
        }

        updateLayout()
    }

    func setBeneficiary(viewModel: ReferendumFullDetailsViewModel.Beneficiary?, locale: Locale) {
        beneficiaryTableView?.clear()
        beneficiaryCell = nil

        if let viewModel = viewModel {
            if beneficiaryTableView == nil {
                let tableView = StackTableView()
                insertView(tableView, afterOneOf: [proposerTableView])
                beneficiaryTableView = tableView
            }

            let beneficiaryCell = createAccountCell(
                with: R.string.localizable.govBeneficiary(preferredLanguages: locale.rLanguages),
                viewModel: viewModel.account
            )

            self.beneficiaryCell = beneficiaryCell

            beneficiaryTableView?.addArrangedSubview(beneficiaryCell)

            if let amount = viewModel.amount {
                let amountCell = createBalanceCell(
                    with: R.string.localizable.govRequestedAmount(preferredLanguages: locale.rLanguages),
                    viewModel: amount
                )

                beneficiaryTableView?.addArrangedSubview(amountCell)
            }
        } else {
            beneficiaryTableView?.removeFromSuperview()
            beneficiaryTableView = nil
        }

        updateLayout()
    }

    func setCurveAndHash(viewModel: ReferendumFullDetailsViewModel.CurveAndHash?, locale: Locale) {
        curveAndHashTableView?.clear()
        curveAndHashTableView = nil

        if let viewModel = viewModel {
            if curveAndHashTableView == nil {
                let tableView = StackTableView()
                insertView(tableView, afterOneOf: [beneficiaryTableView, proposerTableView])
                curveAndHashTableView = tableView
            }

            let approveCurveCell = createTitleValueCell(
                with: R.string.localizable.govApproveCurve(preferredLanguages: locale.rLanguages),
                value: viewModel.approveCurve
            )

            curveAndHashTableView?.addArrangedSubview(approveCurveCell)

            let supportCurveCell = createTitleValueCell(
                with: R.string.localizable.govSupportCurve(preferredLanguages: locale.rLanguages),
                value: viewModel.supportCurve
            )

            curveAndHashTableView?.addArrangedSubview(supportCurveCell)

            if let callHash = viewModel.callHash {
                let callHashCell = createInfoCell(
                    with: R.string.localizable.govCallHash(preferredLanguages: locale.rLanguages),
                    value: callHash
                )

                callHashCell.detailsLabel.lineBreakMode = .byTruncatingMiddle

                curveAndHashTableView?.addArrangedSubview(callHashCell)
                self.callHashCell = callHashCell
            }
        } else {
            curveAndHashTableView?.removeFromSuperview()
            curveAndHashTableView = nil
        }

        updateLayout()
    }

    func setJson(viewModel: String?, locale: Locale) {
        jsonView?.removeFromSuperview()
        jsonView = nil

        if let viewModel = viewModel {
            let jsonView: GenericMultiValueView<BlurredView<UITextView>> = .create {
                $0.valueTop.apply(style: .caption1White64)
                $0.valueTop.textAlignment = .left
                $0.spacing = 12.0

                let textView = $0.valueBottom.view
                textView.isEditable = false
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.isScrollEnabled = false
                textView.backgroundColor = .clear
                textView.textAlignment = .left

                $0.valueBottom.contentInsets = .zero
                $0.valueBottom.innerInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            }

            jsonView.valueTop.text = R.string.localizable.govParametersJson(preferredLanguages: locale.rLanguages)

            jsonView.valueBottom.view.text = viewModel
            containerView.stackView.addArrangedSubview(jsonView)

            self.jsonView = jsonView
        }
    }

    func setTooLongJson(for locale: Locale) {
        jsonView?.removeFromSuperview()

        let jsonView: GenericMultiValueView<EmptyStateView> = .create {
            $0.valueTop.apply(style: .caption1White64)
            $0.valueTop.textAlignment = .left
            $0.spacing = 12.0

            let emptyStateView = $0.valueBottom
            emptyStateView.image = R.image.iconEmptySearch()
            emptyStateView.titleFont = .regularFootnote
            emptyStateView.titleColor = R.color.colorWhite64()!
            emptyStateView.verticalSpacing = 0.0
        }

        jsonView.valueTop.text = R.string.localizable.govParametersJson(preferredLanguages: locale.rLanguages)

        jsonView.valueBottom.title = R.string.localizable.commonTooLongPreview(
            preferredLanguages: locale.rLanguages
        )

        containerView.stackView.addArrangedSubview(jsonView)
        jsonView.snp.makeConstraints {
            $0.height.equalTo(150)
        }

        self.jsonView = jsonView
    }

    private func insertView(_ view: UIView, afterOneOf subviews: [UIView?]) {
        if let optSubview = subviews.first(where: { $0 != nil }), let subview = optSubview {
            containerView.stackView.insertArranged(view: view, after: subview)
        } else {
            containerView.stackView.insertArrangedSubview(view, at: 0)
        }
    }

    private func createAccountCell(with title: String, viewModel: DisplayAddressViewModel) -> StackInfoTableCell {
        let cell = StackInfoTableCell()
        cell.titleLabel.text = title
        cell.detailsLabel.lineBreakMode = viewModel.lineBreakMode
        cell.bind(viewModel: viewModel.cellViewModel)
        return cell
    }

    private func createBalanceCell(
        with title: String,
        viewModel: BalanceViewModelProtocol
    ) -> StackTitleMultiValueCell {
        let cell = StackTitleMultiValueCell()
        cell.canSelect = false
        cell.titleLabel.text = title
        cell.rowContentView.valueView.bind(topValue: viewModel.amount, bottomValue: viewModel.price)
        cell.rowContentView.titleView.hidesIcon = true
        return cell
    }

    private func createTitleValueCell(with title: String, value: String) -> StackTableCell {
        let cell = StackTableCell()
        cell.titleLabel.text = title
        cell.bind(details: value)
        return cell
    }

    private func createInfoCell(with title: String, value: String) -> StackInfoTableCell {
        let cell = StackInfoTableCell()
        cell.titleLabel.text = title
        cell.bind(details: value)
        return cell
    }

    private func updateLayout() {
        let views: [UIView?] = [proposerTableView, beneficiaryTableView, curveAndHashTableView]
        views.forEach {
            if let view = $0 {
                containerView.stackView.setCustomSpacing(8.0, after: view)
            }
        }

        if let optView = views.reversed().first(where: { $0 != nil }), let lastView = optView {
            containerView.stackView.setCustomSpacing(24.0, after: lastView)
        }
    }
}
