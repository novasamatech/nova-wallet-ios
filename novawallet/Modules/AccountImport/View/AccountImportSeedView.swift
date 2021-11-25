import UIKit
import SoraUI
import SoraFoundation

final class AccountImportSeedView: AccountImportBaseView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let seedBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let seedTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    let seedHintLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    let seedTextView: UITextView = {
        let view = UITextView()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.tintColor = R.color.colorWhite()
        return view
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    private(set) var sourceViewModel: InputViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
        seedTextView.text = viewModel.inputHandler.value
    }

    override func setupLocalization() {
        titleLabel.text = "Enter your raw seed"
        seedTitleLabel.text = "Raw seed"
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).inset(UIConstants.verticalTitleInset)
        }

        addSubview(seedBackgroundView)
        seedBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(24.0)
        }

        seedBackgroundView.addSubview(seedTitleLabel)
        seedTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.leading.equalToSuperview().inset(16.0)
        }

        seedBackgroundView.addSubview(seedHintLabel)
        seedHintLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.leading.greaterThanOrEqualTo(seedTitleLabel.snp.trailing).offset(4.0)
        }

        seedBackgroundView.addSubview(seedTextView)
        seedTextView.snp.makeConstraints { make in
            make.top.equalTo(seedTitleLabel.snp.bottom).offset(4.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(16.0)
            make.height.greaterThanOrEqualTo(36.0)
        }
    }
}
