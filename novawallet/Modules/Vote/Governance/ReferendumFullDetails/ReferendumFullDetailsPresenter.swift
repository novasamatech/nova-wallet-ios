import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

final class ReferendumFullDetailsPresenter {
    weak var view: ReferendumFullDetailsViewProtocol?
    let wireframe: ReferendumFullDetailsWireframeProtocol
    let interactor: ReferendumFullDetailsInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let addressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let logger: LoggerProtocol

    let chain: ChainModel
    let referendum: ReferendumLocal
    let actionDetails: ReferendumActionLocal
    let identities: [AccountAddress: AccountIdentity]

    private var price: PriceData?
    private var call: ReferendumActionLocal.Call<String>?

    init(
        interactor: ReferendumFullDetailsInteractorInputProtocol,
        wireframe: ReferendumFullDetailsWireframeProtocol,
        chain: ChainModel,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity],
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        addressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.referendum = referendum
        self.actionDetails = actionDetails
        self.identities = identities
        self.logger = logger
        self.balanceViewModelFactory = balanceViewModelFactory
        self.addressViewModelFactory = addressViewModelFactory
        self.localizationManager = localizationManager
    }

    private func getAccountViewModel(_ accountId: AccountId?) -> DisplayAddressViewModel? {
        guard let accountId = accountId,
              let address = try? accountId.toAddress(using: chain.chainFormat) else {
            return nil
        }

        let displayAddress = DisplayAddress(
            address: address,
            username: identities[address]?.displayName ?? ""
        )

        return addressViewModelFactory.createViewModel(from: displayAddress)
    }

    private func getBalanceViewModel(_ amount: BigUInt?, locale: Locale) -> BalanceViewModelProtocol? {
        guard
            let amount = amount,
            let assetInfo = chain.utilityAsset()?.displayInfo,
            let amountDecimal = Decimal.fromSubstrateAmount(amount, precision: assetInfo.assetPrecision) else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(
            amountDecimal,
            priceData: price
        ).value(for: locale)
    }

    private func provideProposerViewModel() {
        guard let proposer = getAccountViewModel(referendum.proposer) else {
            view?.didReceive(proposer: nil)
            return
        }

        let deposit = getBalanceViewModel(referendum.deposit, locale: selectedLocale)
        view?.didReceive(proposer: .init(proposer: proposer, deposit: deposit))
    }

    private func provideBeneficiaryViewModel() {
        guard
            let beneficiary = getAccountViewModel(
                actionDetails.amountSpendDetails?.beneficiary.accountId
            ),
            let amount = getBalanceViewModel(
                actionDetails.amountSpendDetails?.amount,
                locale: selectedLocale
            ) else {
            view?.didReceive(beneficiary: nil)
            return
        }

        view?.didReceive(beneficiary: .init(account: beneficiary, amount: amount))
    }

    private func provideCurveAndHashViewModel() {
        guard
            let approvalCurve = referendum.state.approvalCurve,
            let supportCurve = referendum.state.supportCurve else {
            return
        }

        let callHash = referendum.state.callHash

        let model = ReferendumFullDetailsViewModel.CurveAndHash(
            approveCurve: approvalCurve.displayName,
            supportCurve: supportCurve.displayName,
            callHash: callHash
        )

        view?.didReceive(params: model)
    }

    private func provideJson() {
        switch call {
        case let .concrete(json):
            view?.didReceive(json: json)
        case .tooLong:
            view?.didReceiveTooLongJson()
        case .none:
            view?.didReceive(json: nil)
        }
    }

    private func updateView() {
        provideProposerViewModel()
        provideBeneficiaryViewModel()
        provideCurveAndHashViewModel()
        provideJson()
    }

    private func presentDetails(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func presentProposer() {
        guard let address = try? referendum.proposer?.toAddress(using: chain.chainFormat) else {
            return
        }

        presentDetails(for: address)
    }

    func presentBeneficiary() {
        guard
            let address = try? actionDetails.amountSpendDetails?.beneficiary.accountId?.toAddress(
                using: chain.chainFormat
            ) else {
            return
        }

        presentDetails(for: address)
    }

    func presentCallHash() {
        guard let view = view, let callHash = referendum.state.callHash else {
            return
        }

        wireframe.presentCopy(from: view, value: callHash, locale: selectedLocale)
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.price = price

        provideProposerViewModel()
        provideBeneficiaryViewModel()
    }

    func didReceive(call: ReferendumActionLocal.Call<String>?) {
        self.call = call
        provideJson()
    }

    func didReceive(error: ReferendumFullDetailsError) {
        logger.error("Did receiver error: \(error)")

        switch error {
        case .priceFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .processingJSON:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshCall()
            }
        }
    }
}

extension ReferendumFullDetailsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
