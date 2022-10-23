import Foundation
import SubstrateSdk
import SoraFoundation

final class ReferendumFullDetailsPresenter {
    weak var view: ReferendumFullDetailsViewProtocol?
    let wireframe: ReferendumFullDetailsWireframeProtocol
    let interactor: ReferendumFullDetailsInteractorInputProtocol
    let chainIconGenerator: IconGenerating
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol

    let chain: ChainModel
    let referendum: ReferendumLocal
    let actionDetails: ReferendumActionLocal
    let identities: [AccountAddress: AccountIdentity]
    private var price: PriceData?
    private var json: String?

    init(
        interactor: ReferendumFullDetailsInteractorInputProtocol,
        wireframe: ReferendumFullDetailsWireframeProtocol,
        chainIconGenerator: IconGenerating,
        chain: ChainModel,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity],
        localizationManager: LocalizationManagerProtocol,
        currencyManager: CurrencyManagerProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactory
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.referendum = referendum
        self.actionDetails = actionDetails
        self.identities = identities
        self.chainIconGenerator = chainIconGenerator
        priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        self.assetFormatterFactory = assetFormatterFactory
        self.currencyManager = currencyManager
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let view = view else {
            return
        }
        getProposer().map {
            view.didReceive(proposerModel: .init(
                title: "Proposer",
                model: .init(
                    details: $0.name,
                    imageViewModel: $0.icon
                )
            ))
        }
        let approvalCurveModel = referendum.state.approvalCurve.map {
            TitleWithSubtitleViewModel(
                title: "Approve Curve",
                subtitle: $0.displayName
            )
        }
        let supportCurveModel = referendum.state.supportCurve.map {
            TitleWithSubtitleViewModel(
                title: "Support Curve",
                subtitle: $0.displayName
            )
        }
        let callHashModel = referendum.state.callHash.map {
            TitleWithSubtitleViewModel(
                title: "Call Hash",
                subtitle: $0
            )
        }

        view.didReceive(
            approveCurve: approvalCurveModel,
            supportCurve: supportCurveModel,
            callHash: callHashModel
        )

        updatePriceDependentViews()
    }

    private func getProposer() -> (name: String, icon: ImageViewModelProtocol?)? {
        guard let proposer = referendum.proposer,
              let proposerAddress = try? proposer.toAddress(using: chain.chainFormat) else {
            return nil
        }

        let chainAccountIcon = icon(
            generator: chainIconGenerator,
            from: proposer
        )

        let name = identities[proposerAddress]?.displayName ?? proposerAddress

        return (name: name, icon: chainAccountIcon)
    }

    private func icon(
        generator: IconGenerating,
        from imageData: Data?
    ) -> DrawableIconViewModel? {
        guard let data = imageData,
              let icon = try? generator.generateFromAccountId(data) else {
            return nil
        }

        return DrawableIconViewModel(icon: icon)
    }

    private func updatePriceDependentViews() {
        guard let utilityAsset = chain.utilityAsset() else {
            return
        }
        guard let amountInPlank = actionDetails.amountSpendDetails?.amount else {
            return
        }
        let amount = Decimal.fromSubstrateAmount(
            amountInPlank,
            precision: Int16(utilityAsset.precision)
        ) ?? 0.0

        let formattedAmount = formatAmount(
            amount,
            assetDisplayInfo: utilityAsset.displayInfo,
            locale: selectedLocale
        )
        let price = formatPrice(amount: amount, priceData: price, locale: selectedLocale)
        view?.didReceive(
            deposit: .init(
                topValue: formattedAmount,
                bottomValue: price
            ),
            title: "Deposit"
        )
    }

    private func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        guard let currencyManager = currencyManager else {
            return ""
        }
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }

    private func formatAmount(
        _ amount: Decimal,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let priceFormatter = assetFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.price = price
        updatePriceDependentViews()
    }

    func didReceive(json: String?) {
        view?.didReceive(json: json, jsonTitle: "Parameters JSON")
    }

    func didReceive(error: ReferendumFullDetailsError) {
        print("Received error: \(error.localizedDescription)")
    }
}

extension ReferendumFullDetailsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}

extension ReferendumFullDetailsPresenter: SelectedCurrencyDepending {
    func applyCurrency() {
        updatePriceDependentViews()
    }
}
