import Foundation
import SoraFoundation
import BigInt
import SubstrateSdk

final class NftDetailsPresenter {
    weak var view: NftDetailsViewProtocol?
    let wireframe: NftDetailsWireframeProtocol
    let interactor: NftDetailsInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quantityFactory: LocalizableResource<NumberFormatter>

    private(set) var loadingProgress: NftDetailsProgress = [] {
        didSet {
            if oldValue != .all, loadingProgress == .all {
                view?.didCompleteRefreshing()
            }
        }
    }

    private lazy var polkadotIconGenerator = PolkadotIconGenerator()
    private lazy var gradientFactory = CSSGradientFactory()

    private var label: NftDetailsLabel?
    private var price: BigUInt?
    private var tokenPriceData: PriceData?
    private var owner: DisplayAddress?
    private var issuer: DisplayAddress?

    init(
        interactor: NftDetailsInteractorInputProtocol,
        wireframe: NftDetailsWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        quantityFactory: LocalizableResource<NumberFormatter>,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.quantityFactory = quantityFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    private func updateLabelViewModel() {
        let labelString: String?

        switch label {
        case let .limited(serialNumber, totalIssuance):
            let snString = quantityFactory.value(for: selectedLocale).string(
                from: NSNumber(value: serialNumber)
            ) ?? ""

            let totalIssuanceString = quantityFactory.value(for: selectedLocale).string(
                from: NSNumber(value: totalIssuance)
            ) ?? ""

            labelString = R.string.localizable.nftListItemLimitedFormat(
                snString,
                totalIssuanceString,
                preferredLanguages: selectedLocale.rLanguages
            )
        case .unlimited:
            labelString = R.string.localizable.nftListItemUnlimited(
                preferredLanguages: selectedLocale.rLanguages
            )
        case let .custom(string):
            labelString = string
        case .none:
            labelString = nil
        }

        view?.didReceive(label: labelString)
    }

    private func updatePriceViewModel() {
        let assetInfo = chainAsset.assetDisplayInfo
        if
            let price = price,
            price > 0,
            let priceDecimal = Decimal.fromSubstrateAmount(
                price,
                precision: assetInfo.assetPrecision
            ) {
            let viewModel = balanceViewModelFactory
                .balanceFromPrice(priceDecimal, priceData: tokenPriceData)
                .value(for: selectedLocale)
            view?.didReceive(price: viewModel)
        } else {
            view?.didReceive(price: nil)
        }
    }

    private func createDisplayAddressViewModel(
        from displayAddress: DisplayAddress
    ) -> DisplayAddressViewModel {
        let imageViewModel: ImageViewModelProtocol?

        if
            let accountId = try? displayAddress.address.toAccountId(),
            let icon = try? polkadotIconGenerator.generateFromAccountId(accountId) {
            imageViewModel = DrawableIconViewModel(icon: icon)
        } else {
            imageViewModel = nil
        }

        let name = displayAddress.username.isEmpty ? nil : displayAddress.username

        return DisplayAddressViewModel(
            address: displayAddress.address,
            name: name,
            imageViewModel: imageViewModel
        )
    }

    private func provideOwner(with displayAddress: DisplayAddress) {
        let ownerViewModel = createDisplayAddressViewModel(from: displayAddress)
        view?.didReceive(ownerViewModel: ownerViewModel)
    }

    private func provideIssuer(with displayAddress: DisplayAddress?) {
        let ownerViewModel = displayAddress.map { createDisplayAddressViewModel(from: $0) }
        view?.didReceive(issuerViewModel: ownerViewModel)
    }

    private func provideCollection(with model: NftDetailsCollection?) {
        if let model = model {
            let imageViewModel = model.imageUrl.map { RemoteImageViewModel(url: $0) }
            let viewModel = StackCellViewModel(details: model.name, imageViewModel: imageViewModel)
            view?.didReceive(collectionViewModel: viewModel)
        } else {
            view?.didReceive(collectionViewModel: nil)
        }
    }

    private func provideNetwork() {
        let color: GradientModel

        if
            let colorString = chainAsset.chain.color,
            let colorModel = gradientFactory.createFromString(colorString) {
            color = colorModel
        } else {
            color = GradientModel.defaultGradient
        }

        let imageViewModel = RemoteImageViewModel(url: chainAsset.chain.icon)

        let viewModel = NetworkViewModel(
            name: chainAsset.chain.name,
            icon: imageViewModel,
            gradient: color
        )

        view?.didReceive(networkViewModel: viewModel)
    }

    private func presentAddressOptions(_ address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }
}

extension NftDetailsPresenter: NftDetailsPresenterProtocol {
    func setup() {
        provideNetwork()

        interactor.setup()
    }

    func refresh() {
        provideNetwork()

        loadingProgress = []

        interactor.refresh()
    }

    func selectOwner() {
        guard let owner = owner else {
            return
        }

        presentAddressOptions(owner.address)
    }

    func selectIssuer() {
        guard let issuer = issuer else {
            return
        }

        presentAddressOptions(issuer.address)
    }
}

extension NftDetailsPresenter: NftDetailsInteractorOutputProtocol {
    func didReceive(name: String?) {
        loadingProgress.formUnion(.name)

        view?.didReceive(name: name)
    }

    func didReceive(label: NftDetailsLabel?) {
        loadingProgress.formUnion(.label)

        self.label = label

        updateLabelViewModel()
    }

    func didReceive(description: String?) {
        loadingProgress.formUnion(.description)

        view?.didReceive(description: description)
    }

    func didReceive(media: NftMediaViewModelProtocol?) {
        loadingProgress.formUnion(.media)

        view?.didReceive(media: media)
    }

    func didReceive(price: BigUInt?, tokenPriceData: PriceData?) {
        loadingProgress.formUnion(.price)

        self.price = price
        self.tokenPriceData = tokenPriceData

        updatePriceViewModel()
    }

    func didReceive(collection: NftDetailsCollection?) {
        loadingProgress.formUnion(.collection)

        provideCollection(with: collection)
    }

    func didReceive(owner: DisplayAddress) {
        loadingProgress.formUnion(.owner)

        self.owner = owner

        provideOwner(with: owner)
    }

    func didReceive(issuer: DisplayAddress?) {
        loadingProgress.formUnion(.issuer)

        self.issuer = issuer

        provideIssuer(with: issuer)
    }

    func didReceive(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
    }
}

extension NftDetailsPresenter: Localizable {
    func applyLocalization() {
        if let isViewLoaded = view?.isSetup, isViewLoaded {
            updateLabelViewModel()
            updatePriceViewModel()
        }
    }
}
