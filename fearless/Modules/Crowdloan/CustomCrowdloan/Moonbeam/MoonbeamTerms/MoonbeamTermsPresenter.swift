import Foundation
import BigInt
import SoraFoundation

final class MoonbeamTermsPresenter {
    weak var view: MoonbeamTermsViewProtocol?
    let assetInfo: AssetBalanceDisplayInfo
    let wireframe: MoonbeamTermsWireframeProtocol
    let interactor: MoonbeamTermsInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var priceData: PriceData?
    private var fee: Decimal?

    init(
        assetInfo: AssetBalanceDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        interactor: MoonbeamTermsInteractorInputProtocol,
        wireframe: MoonbeamTermsWireframeProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.assetInfo = assetInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }

    private func updateView() {
        provideFeeViewModel()
    }

    private func provideFeeViewModel() {
        guard let fee = fee else { return }
        let feeViewModel = balanceViewModelFactory
            .balanceFromPrice(fee, priceData: priceData)
        view?.didReceiveFee(viewModel: feeViewModel)
    }
}

extension MoonbeamTermsPresenter: MoonbeamTermsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleAction() {
        view?.didStartLoading()
        interactor.submitAgreement()
    }

    func handleLearnTerms() {
        guard let view = view else { return }
        wireframe.showWeb(url: interactor.termsURL, from: view, style: .automatic)
    }
}

extension MoonbeamTermsPresenter: MoonbeamTermsInteractorOutputProtocol {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveRemark(result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(remark):
            print(remark)
        case let .failure(error):
            logger?.error("Did receive remark error: \(error)")
        }
    }

    func didReceiveExtrinsicStatus(result: Result<ExtrinsicStatus, Error>) {
        switch result {
        case let .success(status):
            if case let .finalized(blockHash) = status {}
        case let .failure(error):
            logger?.error("Did receive remark error: \(error)")
        }
    }
}
