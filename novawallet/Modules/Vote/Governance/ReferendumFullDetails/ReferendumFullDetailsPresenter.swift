import Foundation
import SubstrateSdk
import Foundation_iOS
import BigInt

final class ReferendumFullDetailsPresenter {
    weak var view: ReferendumFullDetailsViewProtocol?
    let wireframe: ReferendumFullDetailsWireframeProtocol
    let interactor: ReferendumFullDetailsInteractorInputProtocol
    let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    let addressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let logger: LoggerProtocol

    let chain: ChainModel
    let referendum: ReferendumLocal
    let actionDetails: ReferendumActionLocal
    let metadata: ReferendumMetadataLocal?
    let identities: [AccountAddress: AccountIdentity]

    private var requestedAmountPrice: PriceData?
    private var utilityAssetPrice: PriceData?
    private var call: ReferendumActionLocal.Call<String>?

    init(
        interactor: ReferendumFullDetailsInteractorInputProtocol,
        wireframe: ReferendumFullDetailsWireframeProtocol,
        chain: ChainModel,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        metadata: ReferendumMetadataLocal?,
        identities: [AccountAddress: AccountIdentity],
        balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol,
        addressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.referendum = referendum
        self.metadata = metadata
        self.actionDetails = actionDetails
        self.identities = identities
        self.logger = logger
        self.balanceViewModelFacade = balanceViewModelFacade
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

    private func getBalanceViewModel(
        _ amount: BigUInt?,
        chainAsset: ChainAsset?,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard
            let amount,
            let assetInfo = chainAsset?.assetDisplayInfo else {
            return nil
        }

        return balanceViewModelFacade.balanceFromPrice(
            targetAssetInfo: assetInfo,
            amount: amount.decimal(assetInfo: assetInfo),
            priceData: priceData
        ).value(for: locale)
    }

    private func provideProposerViewModel() {
        let optProposerId = referendum.proposer ?? metadata?.proposerAccountId(for: chain.chainFormat)
        guard let proposer = getAccountViewModel(optProposerId) else {
            view?.didReceive(proposer: nil)
            return
        }

        let deposit = getBalanceViewModel(
            referendum.deposit,
            chainAsset: chain.utilityChainAsset(),
            priceData: utilityAssetPrice,
            locale: selectedLocale
        )
        view?.didReceive(proposer: .init(proposer: proposer, deposit: deposit))
    }

    private func provideBeneficiaryViewModel() {
        guard
            let beneficiary = getAccountViewModel(
                actionDetails.beneficiary
            ),
            let requestedAmount = actionDetails.requestedAmount(),
            let amount = getBalanceViewModel(
                requestedAmount.value,
                chainAsset: requestedAmount.otherChainAssetOrCurrentUtility(from: chain),
                priceData: requestedAmountPrice,
                locale: selectedLocale
            ) else {
            view?.didReceive(beneficiary: nil)
            return
        }

        view?.didReceive(beneficiary: .init(account: beneficiary, amount: amount))
    }

    private func provideCurveAndHashViewModel() {
        guard
            let functionInfo = referendum.state.functionInfo(locale: selectedLocale),
            let turnout = referendum.state.turnout,
            let electorate = referendum.state.electorate,
            let turnoutBalance = getBalanceViewModel(
                turnout,
                chainAsset: chain.utilityChainAsset(),
                priceData: utilityAssetPrice,
                locale: selectedLocale
            ),
            let electorateBalance = getBalanceViewModel(
                electorate,
                chainAsset: chain.utilityChainAsset(),
                priceData: utilityAssetPrice,
                locale: selectedLocale
            ) else {
            return
        }

        let callHash = referendum.state.callHash

        let model = ReferendumFullDetailsViewModel.Voting(
            functionInfo: functionInfo,
            turnout: turnoutBalance,
            electorate: electorateBalance,
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
        let optAccountId = referendum.proposer ?? metadata?.proposerAccountId(for: chain.chainFormat)
        guard let address = try? optAccountId?.toAddress(using: chain.chainFormat) else {
            return
        }

        presentDetails(for: address)
    }

    func presentBeneficiary() {
        guard
            let address = try? actionDetails.beneficiary?.toAddress(
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
    func didReceiveRequestedAmount(price: PriceData?) {
        requestedAmountPrice = price

        provideProposerViewModel()
        provideBeneficiaryViewModel()
        provideCurveAndHashViewModel()
    }

    func didReceiveUtilityAsset(price: PriceData?) {
        utilityAssetPrice = price

        provideProposerViewModel()
        provideBeneficiaryViewModel()
        provideCurveAndHashViewModel()
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
