import UIKit
import CommonWallet
import SoraUI

final class OperationDetailsViewLayout: UIView {
    enum Constants {
        static let iconSize = CGSize(width: 64.0, height: 64.0)
        static let imageInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)

        static var imageSize: CGSize {
            let width = iconSize.width - imageInsets.left - imageInsets.right
            let height = iconSize.height - imageInsets.top - imageInsets.bottom

            return CGSize(width: width, height: height)
        }
    }

    let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: false)
        view.stackView.alignment = .center
        view.stackView.layoutMargins = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    let iconView: AssetIconView = {
        let view = AssetIconView()
        view.backgroundView.cornerRadius = Constants.iconSize.height / 2.0
        view.backgroundView.fillColor = R.color.colorWhite16()!
        view.backgroundView.highlightedFillColor = R.color.colorWhite16()!
        view.backgroundView.strokeColor = R.color.colorWhite8()!
        view.contentInsets = Constants.imageInsets
        view.imageView.tintColor = R.color.colorTransparentText()
        return view
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .largeTitle
        label.textAlignment = .center
        return label
    }()

    let statusView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .iconDetails
        view.spacing = 4.0
        view.detailsLabel.numberOfLines = 1
        view.detailsLabel.font = .semiBoldCaps2
        return view
    }()

    private(set) var actionButton: TriangularedButton?

    private var operationView: LocalizableView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLocalizableView<T: LocalizableView>() -> T {
        if let targetView = operationView as? T {
            return targetView
        }

        operationView?.removeFromSuperview()

        let targetView = T()
        operationView = targetView

        containerView.stackView.addArrangedSubview(targetView)
        targetView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
        }

        return targetView
    }

    func setupActionButton() -> TriangularedButton {
        if let actionButton = actionButton {
            return actionButton
        }

        let actionButton = TriangularedButton()
        actionButton.applyDefaultStyle()
        actionButton.applyEnabledStyle()
        actionButton.triangularedView?.sideLength = 12.0
        self.actionButton = actionButton

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
                .offset(-UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        return actionButton
    }

    func removeActionButton() {
        actionButton?.removeFromSuperview()
        actionButton = nil

        containerView.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        containerView.stackView.setCustomSpacing(16.0, after: iconView)

        containerView.stackView.addArrangedSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(2 * UIConstants.horizontalInset)
        }

        containerView.stackView.setCustomSpacing(10.0, after: amountLabel)

        containerView.stackView.addArrangedSubview(statusView)
        containerView.stackView.setCustomSpacing(24.0, after: statusView)
    }
}
