import UIKit
import SoraUI

final class ExportGenericViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .fill
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: UIConstants.verticalTitleInset,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let sourceBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView(filled: true)

    let sourceTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    let sourceDetailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let sourceHintLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    let hintLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    private(set) var actionButton: TriangularedButton?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupActionButton() {
        guard actionButton == nil else {
            return
        }

        let button = TriangularedButton()
        button.applyDefaultStyle()
        actionButton = button

        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.scrollBottomOffset = UIConstants.actionBottomInset + UIConstants.actionHeight + 16.0
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(12.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(subtitleLabel)
        containerView.stackView.setCustomSpacing(16.0, after: subtitleLabel)

        containerView.stackView.addArrangedSubview(sourceBackgroundView)
        sourceBackgroundView.addSubview(sourceTitleLabel)
        sourceTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(8.0)
        }

        sourceBackgroundView.addSubview(sourceHintLabel)
        sourceHintLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(8.0)
            make.leading.greaterThanOrEqualTo(sourceTitleLabel.snp.trailing).offset(4.0)
        }

        sourceBackgroundView.addSubview(sourceDetailsLabel)
        sourceDetailsLabel.snp.makeConstraints { make in
            make.trailing.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(sourceTitleLabel.snp.bottom).offset(4.0)
            make.bottom.equalToSuperview().inset(17.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: sourceBackgroundView)

        containerView.stackView.addArrangedSubview(hintLabel)
    }
}
