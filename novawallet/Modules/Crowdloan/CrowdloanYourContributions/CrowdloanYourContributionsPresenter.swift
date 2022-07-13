import Foundation

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol
    let input: CrowdloanYourContributionsViewInput
    let viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol
    let logger: LoggerProtocol?

    private var externalContributions: [ExternalContribution]?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var leasingPeriod: LeasingPeriod?
    private var price: PriceData?

    private var crowloanMetadata: CrowdloanMetadata? {
        guard
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod else {
            return nil
        }

        return CrowdloanMetadata(
            blockNumber: blockNumber,
            blockDuration: blockDuration,
            leasingPeriod: leasingPeriod
        )
    }

    init(
        input: CrowdloanYourContributionsViewInput,
        viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol,
        interactor: CrowdloanYourContributionsInteractorInputProtocol,
        wireframe: CrowdloanYourContributionsWireframeProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(
            for: input.crowdloans,
            contributions: input.contributions,
            externalContributions: externalContributions,
            displayInfo: input.displayInfo,
            chainAsset: input.chainAsset,
            locale: view?.selectedLocale ?? .current
        )
        view?.reload(contributions: viewModel.contributions)
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsInteractorOutputProtocol {
    func didReceiveExternalContributions(_ externalContributions: [ExternalContribution]) {
        let positiveContributions = externalContributions.filter { $0.amount > 0 }
        self.externalContributions = positiveContributions
        if !positiveContributions.isEmpty {
            updateView()
        }
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber?) {
        self.blockNumber = blockNumber

        updateView()
    }

    func didReceiveBlockDuration(_ blockDuration: BlockTime) {
        self.blockDuration = blockDuration
    }

    func didReceiveLeasingPeriod(_ leasingPeriod: LeasingPeriod) {
        self.leasingPeriod = leasingPeriod

        updateView()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.price = priceData

        updateView()
    }

    func didReceiveError(_ error: Error) {
        logger?.error("Did receive external contributions error: \(error)")
    }
}
