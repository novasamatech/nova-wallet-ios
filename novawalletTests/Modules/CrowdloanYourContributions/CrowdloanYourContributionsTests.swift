import XCTest
import Foundation_iOS
import BigInt
import Operation_iOS
import SubstrateSdk
import Cuckoo
@testable import novawallet

final class CrowdloanYourContributionsTests: XCTestCase {
    private let crowdloans: [Crowdloan] = [.active, .ended]
    private let externalContributions: [ExternalContribution] = [.sample]
    private lazy var contributions: CrowdloanContributionDict = [
        Crowdloan.active.fundIndex: .sample,
        Crowdloan.ended.fundIndex: .sample
    ]
    
    func testPresenterSetup() {
        let view = MockCrowdloanYourContributionsViewProtocol()
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            hasCrowdloans: true
        )
        let presenter = createPresenter(for: view,
                                        chain: chain)
        
        let reloadModelExpectation = XCTestExpectation()
        let returnInIntervalsExpectation = XCTestExpectation()
        
        var contributionsViewModel: [CrowdloanContributionViewModel] = []
        var returnInIntervals: [FormattedReturnInIntervalsViewModel] = []
        
        stub(view) { stub in
            stub.reload(model: any()).then { model in
                contributionsViewModel = model.sections.compactMap(Prism.contributionViewModels.get).first ?? []
                reloadModelExpectation.fulfill()
            }
            
            stub.reload(returnInIntervals: any()).then { intervals in
                returnInIntervals = intervals
                returnInIntervalsExpectation.fulfill()
            }
            stub.isSetup.get.thenReturn(false, true)
        }
        
        XCTAssertNotNil(presenter)
        presenter?.setup()
        
        wait(for: [reloadModelExpectation, returnInIntervalsExpectation], timeout: 10)
        
        XCTAssertEqual(contributionsViewModel.count, 3)
        XCTAssertEqual(returnInIntervals.compactMap { $0.interval }.count, 2)
    }
    
    private func createPresenter(
        for view: CrowdloanYourContributionsViewProtocol,
        chain: ChainModel
    ) -> CrowdloanYourContributionsPresenterProtocol? {
        guard let interactor = createInteractor(chain: chain),
              let input = createInput(from: chain) else {
            return nil
        }
        let wireframe = CrowdloanYourContributionsWireframeProtocolStub()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        let viewModelFactory = CrowdloanYourContributionsVMFactory(chainDateCalculator: ChainDateCalculator(),
                                                                   calendar: Calendar.current,
                                                                   balanceViewModelFactoryFacade: balanceViewModelFactoryFacade)
        
        let presenter = CrowdloanYourContributionsPresenter(input: input,
                                                            viewModelFactory: viewModelFactory,
                                                            interactor: interactor,
                                                            wireframe: wireframe,
                                                            timeFormatter: TotalTimeFormatter(),
                                                            localizationManager: LocalizationManager.shared,
                                                            crowdloansCalculator: CrowdloansCalculator())
        presenter.view = view
        interactor.presenter = presenter
        return presenter
    }
    
    private func createInput(from chain: ChainModel) -> CrowdloanYourContributionsViewInput? {
        guard let asset = chain.assets.first?.displayInfo else {
            return nil
        }
        let chainAsset = ChainAssetDisplayInfo(asset: asset,
                                               chain: chain.chainFormat)
        let input = CrowdloanYourContributionsViewInput(crowdloans: crowdloans,
                                                        contributions: contributions,
                                                        displayInfo: nil,
                                                        chainAsset: chainAsset)
        return input
    }
    
    private func createInteractor(chain: ChainModel) -> CrowdloanYourContributionsInteractor? {
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }
        let crowdloanSubscriptionFactory = CrowdloanLocalSubscriptionFactoryStub(blockNumber: Crowdloan.currentBlockNumber)
        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(
                identifier: "id",
                price: "100",
                dayChange: 0.01,
                currencyId: Currency.usd.id
            )
        )
        let crowdloanOffchainProviderFactory = CrowdloanOffchainProviderFactoryStub(
            externalContributions: externalContributions
        )
        let selectedMetaAccount = AccountGenerator.generateMetaAccount()
        
        return CrowdloanYourContributionsInteractor(chain: chain,
                                                    selectedMetaAccount: selectedMetaAccount,
                                                    operationManager: OperationManager(),
                                                    runtimeService: runtimeService,
                                                    crowdloanLocalSubscriptionFactory: crowdloanSubscriptionFactory,
                                                    crowdloanOffchainProviderFactory: crowdloanOffchainProviderFactory,
                                                    priceLocalSubscriptionFactory: priceProviderFactory,
                                                    currencyManager: CurrencyManagerStub())
    }
}
