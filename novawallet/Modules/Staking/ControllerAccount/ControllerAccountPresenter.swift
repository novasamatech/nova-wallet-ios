import Foundation
import SoraFoundation
import BigInt

final class ControllerAccountPresenter {
    let wireframe: ControllerAccountWireframeProtocol
    let interactor: ControllerAccountInteractorInputProtocol
    let viewModelFactory: ControllerAccountViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let explorers: [ChainModel.Explorer]?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    weak var view: ControllerAccountViewProtocol?

    private let logger: LoggerProtocol?
    private var stashAccountItem: MetaChainAccountResponse?
    private var stashItem: StashItem?
    private var chosenAccountItem: MetaChainAccountResponse?
    private var accounts: [MetaChainAccountResponse]?
    private var canChooseOtherController = false
    private var fee: Decimal?
    private var balance: Decimal?
    private var controllerBalance: Decimal?
    private var stakingLedger: StakingLedger?

    init(
        wireframe: ControllerAccountWireframeProtocol,
        interactor: ControllerAccountInteractorInputProtocol,
        viewModelFactory: ControllerAccountViewModelFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        explorers: [ChainModel.Explorer]?,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.viewModelFactory = viewModelFactory
        self.applicationConfig = applicationConfig
        self.assetInfo = assetInfo
        self.dataValidatingFactory = dataValidatingFactory
        self.explorers = explorers
        self.logger = logger
    }

    private func updateView() {
        guard let stashItem = stashItem else {
            return
        }
        let viewModel = viewModelFactory.createViewModel(
            stashItem: stashItem,
            stashAccountItem: stashAccountItem,
            chosenAccountItem: chosenAccountItem
        )
        canChooseOtherController = viewModel.canChooseOtherController
        view?.reload(with: viewModel)
    }

    func refreshFeeIfNeeded() {
        guard fee == nil else { return }

        if let stashAccountItem = stashAccountItem {
            interactor.estimateFee(for: stashAccountItem.chainAccount)
        } else if let chosenAccountItem = chosenAccountItem {
            interactor.estimateFee(for: chosenAccountItem.chainAccount)
        }
    }

    private func refreshControllerInfoIfNeeded() {
        guard let chosenControllerAddress = chosenAccountItem?.chainAccount.toAddress() else {
            return
        }

        if chosenControllerAddress != stashItem?.controller {
            stakingLedger = nil
            controllerBalance = nil
            interactor.fetchLedger(controllerAddress: chosenControllerAddress)
            interactor.fetchControllerAccountInfo(controllerAddress: chosenControllerAddress)
        }
    }
}

extension ControllerAccountPresenter: ControllerAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleControllerAction() {
        guard canChooseOtherController else {
            presentAccountOptions(for: stashItem?.controller)
            return
        }

        guard let accounts = accounts else {
            return
        }
        let context = PrimitiveContextWrapper(value: accounts)
        let title = LocalizableResource<String> { locale in
            R.string.localizable.stakingControllerSelectTitle(
                preferredLanguages: locale.rLanguages
            )
        }

        wireframe.presentAccountSelection(
            accounts,
            selectedAccountItem: chosenAccountItem,
            title: title,
            delegate: self,
            from: view,
            context: context
        )
    }

    func handleStashAction() {
        presentAccountOptions(for: stashItem?.stash)
    }

    private func presentAccountOptions(for address: AccountAddress?) {
        guard let view = view, let address = address else { return }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: explorers,
            locale: view.localizationManager?.selectedLocale ?? .current
        )
    }

    func selectLearnMore() {
        guard let view = view else { return }
        wireframe.showWeb(
            url: applicationConfig.learnControllerAccountURL,
            from: view,
            style: .automatic
        )
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),
            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                locale: locale
            ),
            dataValidatingFactory.controllerBalanceIsNotZero(controllerBalance, locale: locale),
            dataValidatingFactory.ledgerNotExist(
                stakingLedger: stakingLedger,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard
                let self = self,
                let controllerAccountItem = self.chosenAccountItem
            else { return }

            self.wireframe.showConfirmation(
                from: self.view,
                controllerAccountItem: controllerAccountItem
            )
        }
    }
}

extension ControllerAccountPresenter: ControllerAccountInteractorOutputProtocol {
    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
            updateView()
            if stashItem == nil {
                wireframe.close(view: view)
            }
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveStashAccount(result: Result<MetaChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            stashAccountItem = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive stash account error: \(error)")
        }
    }

    func didReceiveControllerAccount(result: Result<MetaChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            chosenAccountItem = accountItem
            updateView()
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveAccounts(result: Result<[MetaChainAccountResponse], Error>) {
        switch result {
        case let .success(accounts):
            self.accounts = accounts
        case let .failure(error):
            logger?.error("Did receive accounts error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: assetInfo.assetPrecision)
            }
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveControllerAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        switch result {
        case let .success(accountInfo):
            let amount = accountInfo.flatMap {
                Decimal.fromSubstrateAmount(
                    $0.data.available,
                    precision: assetInfo.assetPrecision
                )
            }

            controllerBalance = amount
        case let .failure(error):
            logger?.error("Controller balance fetch error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        switch result {
        case let .success(accountInfo):
            let amount = accountInfo.flatMap {
                Decimal.fromSubstrateAmount(
                    $0.data.available,
                    precision: assetInfo.assetPrecision
                )
            }

            balance = amount
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }
}

extension ControllerAccountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didCompleteControllerSelection()
    }

    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        view?.didCompleteControllerSelection()

        guard let accounts = (context as? PrimitiveContextWrapper<[MetaChainAccountResponse]>)?.value else {
            return
        }

        chosenAccountItem = accounts[index]
        refreshControllerInfoIfNeeded()
        updateView()
    }
}
