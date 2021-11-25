import UIKit
import SoraUI
import SoraFoundation

final class AccountImportKeystoreView: AccountImportBaseView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let uploadView: DetailsTriangularedView = {
        let view = UIFactory.default.createDetailsView(
            with: .largeIconTitleSubtitle,
            filled: false
        )

        view.actionImage = R.image.iconUpload()

        return view
    }()

    let passwordBackroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let passwordView: AnimatedTextField = UIFactory.default.createAnimatedTextField()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?

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
        updateUploadView()
    }

    func bindPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel
        passwordView.text = viewModel.inputHandler.value
    }

    override func setupLocalization() {
        titleLabel.text = "Provide your Restore JSON"
        uploadView.titleLabel.text = "Restore JSON"

        updateUploadView()
    }

    private func updateUploadView() {
        if let viewModel = sourceViewModel, !viewModel.inputHandler.normalizedValue.isEmpty {
            uploadView.subtitleLabel?.textColor = R.color.colorWhite()
            uploadView.subtitle = viewModel.inputHandler.normalizedValue
        } else {
            uploadView.subtitleLabel?.textColor = R.color.colorLightGray()

            uploadView.subtitle = R.string.localizable.recoverJsonHint(preferredLanguages: locale?.rLanguages)
        }
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).inset(UIConstants.verticalTitleInset)
        }

        addSubview(uploadView)
        uploadView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(24.0)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        addSubview(passwordBackroundView)
        passwordBackroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(uploadView.snp.bottom).offset(16.0)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        passwordBackroundView.addSubview(passwordView)
        passwordView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
