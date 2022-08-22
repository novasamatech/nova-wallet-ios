import XCTest
import SoraFoundation
import BigInt
import RobinHood
import SubstrateSdk
import Cuckoo

@testable import novawallet

final class CrowdloanYourContributionsTests: XCTestCase {
    static let currentBlockNumber: BlockNumber = 1337

    let crowdloans: [Crowdloan] = [
        Crowdloan(
            paraId: 2000,
            fundInfo: CrowdloanFunds(
                depositor: Data(repeating: 0, count: 32),
                verifier: nil,
                deposit: 100,
                raised: 100,
                end: currentBlockNumber + 100,
                cap: 1000,
                lastContribution: .never,
                firstPeriod: 100,
                lastPeriod: 101,
                trieIndex: nil,
                fundIndex: StringScaleMapper(value: 1)
            )
        )
    ]

    let externalContributions: [ExternalContribution] = [
        ExternalContribution(source: nil, amount: BigUInt(1000000), paraId: 2000)
    ]
    
    let contributions: CrowdloanContributionDict = [
        1: .init(balance: 10362973, memo: Data())
    ]
    
    func testSetup() {
        let view = MockCrowdloanYourContributionsViewProtocol()
        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            hasCrowdloans: true
        )
        let presenter = createPresenter(for: view,
                                        chain: selectedChain)
        
        let reloadModelExpectation = XCTestExpectation()
        let returnInIntervalsExpectation = XCTestExpectation()
     
        var viewModel: CrowdloanYourContributionsViewModel?
        var returnInIntervals: [FormattedReturnInIntervalsViewModel] = []
        stub(view) { stub in
            stub.reload(model: any()).then { model in
                viewModel = model
                reloadModelExpectation.fulfill()
            }
            
            stub.reload(returnInIntervals: any()).then { intervals in
                returnInIntervals = intervals
                returnInIntervalsExpectation.fulfill()
            }
            stub.isSetup.get.thenReturn(false, true)
        }
        
        presenter?.setup()
    
        wait(for: [reloadModelExpectation, returnInIntervalsExpectation], timeout: 10)
        
        XCTAssertNotNil(viewModel)
        
        let contributions = CrowdloanYourContributionsSection.contributions.get(viewModel!.sections[1])
        XCTAssertEqual(contributions?.count, 2)
        XCTAssertEqual(returnInIntervals.compactMap { $0.interval }.count, 2)
    }
    
    private func createPresenter(
        for view: CrowdloanYourContributionsViewProtocol,
        chain: ChainModel
    ) -> CrowdloanYourContributionsPresenterProtocol? {
        let wireframe = MockCrowdloanYourContributionsWireframeProtocol()
    
        let chainAsset = ChainAssetDisplayInfo(asset: chain.assets.first!.displayInfo,
                                               chain: chain.chainFormat)
        let input = CrowdloanYourContributionsViewInput(crowdloans: crowdloans,
                                                        contributions: contributions,
                                                        displayInfo: nil,
                                                        chainAsset: chainAsset)
        let currencyManager = CurrencyManagerStub()
        let selectedAccount = AccountGenerator.generateMetaAccount()
    
        let viewModelFactory = CrowdloanYourContributionsVMFactory(chainDateCalculator: ChainDateCalculator(),
                                                                   calendar: Calendar.current,
                                                                   balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)))
        guard let interactor = createInteractor(chain: chain,
                                                selectedMetaAccount: selectedAccount) else {
            return nil
        }
        
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

    private func createInteractor(chain: ChainModel,
                                  selectedMetaAccount: MetaAccountModel) -> CrowdloanYourContributionsInteractor? {
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }
        let crowdloanSubscriptionFactory = CrowdloanLocalSubscriptionFactoryStub(
            blockNumber: Self.currentBlockNumber,
            crowdloanFunds: crowdloans[0].fundInfo
        )
        
        let priceProviderFactory = PriceProviderFactoryStub(
            priceData: PriceData(price: "100", dayChange: 0.01, currencyId: Currency.usd.id)
        )
        
        let crowdloanOffchainProviderFactory = CrowdloanOffchainProviderFactoryStub(
            externalContributions: externalContributions
        )
        
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

extension CrowdloanYourContributionsSection {
    static var contributions: GenericPrism<CrowdloanYourContributionsSection, [CrowdloanContributionViewModel]> {
        return .init(
            get: {
                guard case .contributions(let output) = $0 else {
                    return nil
                }
                return output
            },
            inject: { .contributions($0) })
    }
}

struct GenericPrism<Whole,Part> {
    let get: (Whole) -> Part?
    let inject: (Part) -> Whole
    
    init(get: @escaping (Whole) -> Part?, inject: @escaping (Part) -> Whole) {
        self.get = get
        self.inject = inject
    }
    
    func then<Subpart>(_ other: GenericPrism<Part,Subpart>) -> GenericPrism<Whole,Subpart> {
        return GenericPrism<Whole,Subpart>(
            get: { self.get($0).flatMap(other.get) },
            inject: { self.inject(other.inject($0)) })
    }
    
}
