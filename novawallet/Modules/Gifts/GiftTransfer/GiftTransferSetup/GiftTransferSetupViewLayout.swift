import Foundation
import UIKit

final class GiftTransferSetupViewLayout: SCSingleActionLayoutView {
    let networkContainerView = GiftSetupNetworkContainerView()

    let feeView: NetworkFeeInfoView = .create { view in
        view.hideInfoIcon()
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    var issueLabel: UILabel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(networkContainerView, spacingAfter: 16.0)
        addArrangedSubview(amountView)
        addArrangedSubview(amountInputView, spacingAfter: 16.0)
        addArrangedSubview(feeView)

        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
    }

    override func setupStyle() {
        super.setupStyle()

        genericActionView.imageWithTitleView?.titleFont = .semiBoldSubheadline
    }
}

// MARK: - Private

private extension GiftTransferSetupViewLayout {
    func setupIssueLabel() -> UILabel {
        if let issueLabel {
            return issueLabel
        }

        let label = UILabel(style: .caption1Negative)
        label.numberOfLines = 0

        insertArrangedSubview(label, after: amountInputView, spacingAfter: 16.0)
        stackView.setCustomSpacing(8.0, after: amountInputView)

        issueLabel = label

        return label
    }
}

// MARK: - Internal

extension GiftTransferSetupViewLayout {
    func hideIssues() {
        issueLabel?.removeFromSuperview()
        issueLabel = nil

        stackView.setCustomSpacing(16, after: amountInputView)

        amountInputView.applyNormalStyle()
    }

    func displayIssue(with attributes: GiftSetupViewIssue.IssueAttributes) {
        let issueLabel = setupIssueLabel()
        issueLabel.text = attributes.issueText

        amountInputView.applyErrorStyle()
    }
}
