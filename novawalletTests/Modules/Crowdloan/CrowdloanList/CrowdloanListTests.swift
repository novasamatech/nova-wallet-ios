import XCTest
@testable import novawallet
import SoraFoundation
import SoraKeystore
import SubstrateSdk
import Cuckoo
import BigInt
import RobinHood

class CrowdloanListTests: XCTestCase {
    static let currentBlockNumber: BlockNumber = 1337

    let activeCrowdloans: [Crowdloan] = [
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
    
    let endedCrowdloans: [Crowdloan] = [
        Crowdloan(
            paraId: 2001,
            fundInfo: CrowdloanFunds(
                depositor: Data(repeating: 1, count: 32),
                verifier: nil,
                deposit: 100,
                raised: 1000,
                end: currentBlockNumber,
                cap: 1000,
                lastContribution: .never,
                firstPeriod: 100,
                lastPeriod: 101,
                trieIndex: nil,
                fundIndex: StringScaleMapper(value: 2)
            )
        )
    ]

    let wonCrowdloans: [Crowdloan] = [
        Crowdloan(
            paraId: 2002,
            fundInfo: CrowdloanFunds(
                depositor: Data(repeating: 2, count: 32),
                verifier: nil,
                deposit: 100,
                raised: 100,
                end: currentBlockNumber + 100,
                cap: 1000,
                lastContribution: .never,
                firstPeriod: 100,
                lastPeriod: 101,
                trieIndex: nil,
                fundIndex: StringScaleMapper(value: 3)
            )
        )
    ]

    let leaseInfo: ParachainLeaseInfoList = [
        ParachainLeaseInfo(param: LeaseParam(paraId: 2000, bidderKey: 1),
                           fundAccountId: Data(repeating: 10, count: 32),
                           leasedAmount: nil
        ),
        ParachainLeaseInfo(param: LeaseParam(paraId: 2001, bidderKey: 2),
                           fundAccountId: Data(repeating: 11, count: 32),
                           leasedAmount: nil
        ),
        ParachainLeaseInfo(param: LeaseParam(paraId: 2002, bidderKey: 3) ,
                           fundAccountId: Data(repeating: 12, count: 32),
                           leasedAmount: 1000
        )
    ]

    func testCrowdloansSuccessRetrieving() throws {
        // given

        let view = MockCrowdloanListViewProtocol()
        let wireframe = MockCrowdloanListWireframeProtocol()

        let expectedActiveParaIds: Set<ParaId> = activeCrowdloans
            .reduce(into: Set<ParaId>()) { (result, crowdloan) in
            result.insert(crowdloan.paraId)
        }

        let expectedCompletedParaIds: Set<ParaId> = (endedCrowdloans + wonCrowdloans)
            .reduce(into: Set<ParaId>()) { (result, crowdloan) in
            result.insert(crowdloan.paraId)
        }

        var actualViewModel: CrowdloansViewModel?

        let chainCompletionExpectation = XCTestExpectation()
        let listCompletionExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)

            stub.didReceive(listState: any()).then { state in
                if case let .loaded(viewModel) = state {
                    actualViewModel = viewModel

                    listCompletionExpectation.fulfill()
                }
            }

            stub.didReceive(chainInfo: any()).then { state in
                chainCompletionExpectation.fulfill()
            }
        }

        guard let presenter = try createPresenter(for: view, wireframe: wireframe) else {
            XCTFail("Initialization failed")
            return
        }

        // when

        presenter.setup()
        presenter.becomeOnline()

        // then

        wait(for: [listCompletionExpectation, chainCompletionExpectation], timeout: 10)

        let yourContributionsCount: Int = {
            let yourContribution = actualViewModel!.sections[0]
            if case let .yourContributions(_, count) = yourContribution {
                return count
            } else {
                return 0
            }
        }()
        
        let actualActiveParaIds: Set<ParaId> = {
            let activeSection = actualViewModel!.sections[1]
            if case let .active(_, cellViewModels) = activeSection {
                return cellViewModels.reduce(into: Set<ParaId>()) { result, viewModel in
                    result.insert(viewModel.paraId)
                }
            } else {
                return Set()
            }
        }()

        let actualCompletedParaIds: Set<ParaId> = {
            let completed = actualViewModel!.sections[2]
            if case let .completed(_, cellViewModels) = completed {
                return cellViewModels.reduce(into: Set<ParaId>()) { result, viewModel in
                    result.insert(viewModel.paraId)
                }
            } else {
                return Set()
            }
        }()

        XCTAssertEqual(expectedActiveParaIds, actualActiveParaIds)
        XCTAssertEqual(expectedCompletedParaIds, actualCompletedParaIds)
        XCTAssertEqual(yourContributionsCount, externalContributions.count)
    }

    private func createPresenter(
        for view: MockCrowdloanListViewProtocol,
        wireframe: MockCrowdloanListWireframeProtocol
    ) throws -> CrowdloanListPresenter? {
        let localizationManager = LocalizationManager.shared
        let selectedAccount = AccountGenerator.generateMetaAccount()
        let selectedChain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            hasCrowdloans: true
        )

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [selectedChain])

        let maybeInteractor = createInteractor(
            selectedAccount: selectedAccount,
            selectedChain: selectedChain,
            chainRegistry: chainRegistry
        )

        guard let interactor = maybeInteractor else {
            return nil
        }

        let wireframe = MockCrowdloanListWireframeProtocol()

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    private func createInteractor(
        selectedAccount: MetaAccountModel,
        selectedChain: ChainModel,
        chainRegistry: ChainRegistryProtocol
    ) -> CrowdloanListInteractor? {
        let settings = CrowdloanChainSettings(
            chainRegistry: chainRegistry,
            settings: InMemorySettingsManager()
        )

        settings.save(value: selectedChain)

        let crowdloans = activeCrowdloans + endedCrowdloans + wonCrowdloans
        let crowdloanOperationFactory = CrowdloansOperationFactoryStub(
            crowdloans: crowdloans,
            parachainLeaseInfo: leaseInfo
        )

        let crowdloanRemoteSubscriptionService = MockCrowdloanRemoteSubscriptionServiceProtocol()
            .applyDefaultStub()

        let crowdloanLocalSubscriptionService = CrowdloanLocalSubscriptionFactoryStub(
            blockNumber: Self.currentBlockNumber
        )

        let walletLocalSubscriptionService = WalletLocalSubscriptionFactoryStub(
            balance: BigUInt(1e+18)
        )

        guard let crowdloanInfoURL = selectedChain.externalApi?.crowdloans?.url else {
            return nil
        }

        let jsonProviderFactory = JsonDataProviderFactoryStub(
            sources: [
                crowdloanInfoURL: CrowdloanDisplayInfoList()
            ]
        )

        let crowdloanOffchainProviderFactory = CrowdloanOffchainProviderFactoryStub(
            externalContributions: externalContributions
        )

        let crowdloanState = CrowdloanSharedState(
            settings: settings,
            crowdloanLocalSubscriptionFactory: crowdloanLocalSubscriptionService,
            crowdloanOffchainProviderFactory: crowdloanOffchainProviderFactory
        )
        
        return CrowdloanListInteractor(
            selectedMetaAccount: selectedAccount,
            crowdloanState: crowdloanState,
            chainRegistry: chainRegistry,
            crowdloanOperationFactory: crowdloanOperationFactory,
            crowdloanRemoteSubscriptionService: crowdloanRemoteSubscriptionService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionService,
            jsonDataProviderFactory: jsonProviderFactory,
            operationManager: OperationManagerFacade.sharedManager,
            applicationHandler: ApplicationHandler()
        )
    }
}
