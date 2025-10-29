import Foundation
import UIKit

final class GiftTransferSetupViewLayout: SCSingleActionLayoutView {
    let networkContainerView = GiftSetupNetworkContainerView()

    let feeView: NetworkFeeInfoView = .create { view in
        view.hideInfoIcon()
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    var issueLabel: UILabel = .create { view in
        view.apply(style: .caption1Negative)
        view.numberOfLines = 0
    }

    let getTokenButton: TriangularedButton = .create {
        $0.applySecondaryDefaultStyle()
        $0.imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()
    }

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
        getTokenButton.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
    }

    override func setupStyle() {
        super.setupStyle()

        genericActionView.imageWithTitleView?.titleFont = .semiBoldSubheadline
    }
}

// MARK: - Private

private extension GiftTransferSetupViewLayout {
    func setupIssueLabel() {
        guard issueLabel.superview == nil else { return }

        insertArrangedSubview(issueLabel, after: amountInputView, spacingAfter: 16.0)
        stackView.setCustomSpacing(8.0, after: amountInputView)
    }

    func setupGetTokenButton() {
        guard getTokenButton.superview == nil else { return }

        insertArrangedSubview(getTokenButton, after: issueLabel, spacingAfter: 16.0)
        stackView.setCustomSpacing(12.0, after: issueLabel)
    }
}

// MARK: - Internal

extension GiftTransferSetupViewLayout {
    func hideIssues() {
        issueLabel.removeFromSuperview()
        getTokenButton.removeFromSuperview()

        stackView.setCustomSpacing(16, after: amountInputView)

        amountInputView.applyNormalStyle()
    }

    func displayIssue(with attributes: GiftSetupViewIssue.IssueAttributes) {
        setupIssueLabel()
        issueLabel.text = attributes.issueText

        amountInputView.applyErrorStyle()

        guard attributes.getTokensButtonVisible else {
            getTokenButton.removeFromSuperview()
            return
        }

        setupGetTokenButton()
    }
}
