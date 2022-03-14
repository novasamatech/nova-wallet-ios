import UIKit

final class OperationDetailsRewardView: LocalizableView {
    let stakingTableView = StackTableView()

    let eventTableView: StackTableView = {
        let view = StackTableView()
        return view
    }()

    private(set) var validatorView: StackInfoTableCell?
    private(set) var eraView: StackTableCell?

    let networkView = StackNetworkCell()

    let eventIdView = StackInfoTableCell()
    let typeView = StackTableCell()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindReward(viewModel: OperationRewardViewModel, networkViewModel: NetworkViewModel) {
        let type = R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
        bindCommon(
            networkViewModel: networkViewModel,
            eventId: viewModel.eventId,
            type: type
        )

        updateValidatorView(for: viewModel.validator)
        updateEraView(for: viewModel.era)
    }

    func bindSlash(viewModel: OperationSlashViewModel, networkViewModel: NetworkViewModel) {
        let type = R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        bindCommon(
            networkViewModel: networkViewModel,
            eventId: viewModel.eventId,
            type: type
        )

        updateValidatorView(for: viewModel.validator)
        updateEraView(for: viewModel.era)
    }

    private func bindCommon(
        networkViewModel: NetworkViewModel,
        eventId: String,
        type: String
    ) {
        networkView.bind(viewModel: networkViewModel)
        eventIdView.bind(details: eventId)
        typeView.bind(details: type)
    }

    private func updateValidatorView(for validator: DisplayAddressViewModel?) {
        if let validator = validator {
            let validatorView = setupValidatorView()
            validatorView.detailsLabel.lineBreakMode = validator.lineBreakMode
            validatorView.bind(viewModel: validator.cellViewModel)
        } else {
            removeValidatorView()
        }
    }

    private func updateEraView(for eraString: String?) {
        if let eraString = eraString {
            let eraView = setupEraView()
            eraView.bind(details: eraString)
        } else {
            removeEraView()
        }
    }

    private func setupLocalization() {
        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages
        )

        eventIdView.titleLabel.text = R.string.localizable.stakingCommonEventId(
            preferredLanguages: locale.rLanguages
        )

        typeView.titleLabel.text = R.string.localizable.stakingAnalyticsDetailsType(
            preferredLanguages: locale.rLanguages
        )

        setupValidatorLocalization()
        setupEraLocalization()
    }

    private func setupValidatorLocalization() {
        validatorView?.titleLabel.text = R.string.localizable.stakingCommonValidator(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupEraLocalization() {
        eraView?.titleLabel.text = R.string.localizable.stakingCommonEra(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupValidatorView() -> StackInfoTableCell {
        if let validatorView = validatorView {
            return validatorView
        }

        let validatorView = StackInfoTableCell()
        stakingTableView.insertArrangedSubview(validatorView, at: 0)

        self.validatorView = validatorView

        setupValidatorLocalization()

        return validatorView
    }

    private func removeValidatorView() {
        validatorView?.removeFromSuperview()
        validatorView = nil
        stakingTableView.updateLayout()
    }

    private func setupEraView() -> StackTableCell {
        if let eraView = eraView {
            return eraView
        }

        let eraView = StackTableCell()
        stakingTableView.insertArranged(view: eraView, before: networkView)

        self.eraView = eraView

        setupEraLocalization()

        return eraView
    }

    private func removeEraView() {
        eraView?.removeFromSuperview()
        eraView = nil
        stakingTableView.updateLayout()
    }

    private func setupLayout() {
        addSubview(stakingTableView)
        stakingTableView.snp.makeConstraints { make in
            make.top.trailing.leading.equalToSuperview()
        }

        stakingTableView.addArrangedSubview(networkView)

        addSubview(eventTableView)
        eventTableView.snp.makeConstraints { make in
            make.top.equalTo(stakingTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        eventTableView.addArrangedSubview(eventIdView)
        eventTableView.addArrangedSubview(typeView)
    }
}
