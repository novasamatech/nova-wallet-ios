import Cuckoo
import Operation_iOS
@testable import novawallet
import XCTest

final class SubtensorPortfolioHistoryLoaderTests: XCTestCase {
    func testLoaderKeepsConfirmedUnlistedSeparateFromFailuresAndAvailableHistory() throws {
        let service = HistoryService()
        let listed = SubtensorPriceHistory(
            subnet: ref(64), period: .week, points: [], changeInTao: nil, changeInFiat: nil
        )
        service.results = [64: .success(.available(listed)), 19: .success(.notListed), 7: .failure(TestError.history)]
        let euro = Currency(id: 1, code: "EUR", name: "Euro", symbol: "€", category: .fiat, isPopular: true, coingeckoId: "eur")

        let histories = try load(service: service, subnets: [ref(64), ref(19), ref(7)], currency: euro).get()

        XCTAssertEqual(histories.period, .week)
        XCTAssertEqual(histories.taoFiat.currencyId, euro.id)
        XCTAssertEqual(histories.subnets, [listed])
        XCTAssertEqual(histories.notListedNetuids, [19])
        XCTAssertEqual(histories.failedNetuids, [7])
        XCTAssertEqual(service.requests.map(\.subnet.netuid), [64, 19, 7])
        XCTAssertTrue(service.requests.allSatisfy { $0.period == .week && $0.currency == euro })
    }

    func testMissingServiceDoesNotConfirmAnAlphaHoldingAsUnlisted() throws {
        let histories = try load(service: nil, subnets: [ref(19)]).get()
        let portfolio = SubtensorPortfolio(
            root: nil,
            subnets: [group(netuid: 19)],
            pricedTaoValue: 3_000_000_000,
            unpricedNetuids: []
        )

        XCTAssertTrue(histories.notListedNetuids.isEmpty)
        XCTAssertTrue(histories.failedNetuids.isEmpty)
        XCTAssertTrue(histories.subnets.isEmpty)
        XCTAssertEqual(calculate(portfolio, histories), SubtensorPortfolioValueSeries(points: [], changeInFiat: nil))
    }

    func testRootOnlyRemainsAvailableWithoutSubnetService() throws {
        let histories = try load(service: nil, subnets: []).get()
        let portfolio = SubtensorPortfolio(
            root: group(netuid: 0), subnets: [], pricedTaoValue: 3_000_000_000, unpricedNetuids: []
        )

        let series = calculate(portfolio, histories)

        XCTAssertEqual(series.points.map(\.taoValue), [3, 3, 3])
        XCTAssertEqual(series.points.map(\.fiatValue), [1200, 1230, 1251])
    }

    func testTaoHistoryFailureFailsWholeLoadDespiteConfirmedUnlistedSubnet() {
        let service = HistoryService()
        service.results = [19: .success(.notListed)]

        let result = load(service: service, subnets: [ref(19)], failTao: true)

        guard case let .failure(error) = result else {
            XCTFail("TAO history failure must not become a flat chart")
            return
        }
        XCTAssertEqual(error as? TestError, .tao)
    }
}

private extension SubtensorPortfolioHistoryLoaderTests {
    enum TestError: Error { case history, tao }

    final class HistoryService: SubtensorPriceHistoryServiceProtocol {
        struct Request {
            let subnet: SubtensorSubnetRef
            let period: SubtensorPricePeriod
            let currency: Currency
        }

        var results: [UInt16: Result<SubtensorPriceHistoryResult, Error>] = [:]
        var requests: [Request] = []

        func createHistoryEntryWrapper(
            for subnet: SubtensorSubnetRef,
            period: SubtensorPricePeriod,
            currency: Currency
        ) -> CompoundOperationWrapper<SubtensorPriceHistoryEntry> {
            requests.append(Request(subnet: subnet, period: period, currency: currency))

            switch results[subnet.netuid] {
            case let .success(result):
                return .createWithResult(SubtensorPriceHistoryEntry(result: result, expiresAt: .distantFuture))
            case let .failure(error):
                return .createWithError(error)
            case .none:
                return .createWithError(TestError.history)
            }
        }

        func createWeeklyChangesWrapper(
            for _: [SubtensorSubnetRef]
        ) -> CompoundOperationWrapper<[SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]> {
            .createWithResult([:])
        }
    }

    func load(
        service: SubtensorPriceHistoryServiceProtocol?,
        subnets: [SubtensorSubnetRef],
        currency: Currency = .usd,
        failTao: Bool = false
    ) -> Result<SubtensorPortfolioPriceHistories, Error> {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        stub(coingecko) { stub in
            when(stub.fetchCacheablePriceHistory(for: any(), currency: any(), period: any())).then { priceId, selectedCurrency, period in
                XCTAssertEqual(priceId, "bittensor")
                XCTAssertEqual(selectedCurrency, currency)
                XCTAssertEqual(period, .month)

                if failTao {
                    return .createWithError(TestError.tao)
                }

                let history = PriceHistory(currencyId: currency.id, items: [
                    PriceHistoryItem(startedAt: 0, value: 400),
                    PriceHistoryItem(startedAt: 302_400, value: 410),
                    PriceHistoryItem(startedAt: 604_800, value: 420)
                ])
                return .createWithResult(.response(history, .reusable(lifetime: 3600)))
            }
        }
        let queue = OperationQueue()
        let loader = SubtensorPortfolioHistoryLoader(
            priceHistoryService: service,
            flowState: SubtensorStakingFlowState(coingeckoOperationFactory: coingecko, operationQueue: queue),
            operationQueue: queue
        )
        let completed = expectation(description: "portfolio histories loaded")
        var result: Result<SubtensorPortfolioPriceHistories, Error> = .failure(CommonError.undefined)

        loader.load(for: .week, subnets: subnets, taoPriceId: "bittensor", currency: currency) {
            XCTAssertTrue(Thread.isMainThread)
            result = $0
            completed.fulfill()
        }
        withExtendedLifetime(loader) {
            wait(for: [completed], timeout: Constants.defaultExpectationDuration)
        }

        verify(coingecko).fetchCacheablePriceHistory(for: equal(to: "bittensor"), currency: equal(to: currency), period: equal(to: .month))
        return result
    }

    func ref(_ netuid: UInt16) -> SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: netuid, registeredAt: 1)
    }

    func group(netuid: UInt16) -> SubtensorPortfolioGroup {
        SubtensorPortfolioGroup(
            netuid: netuid, positions: [], totalAlpha: 3_000_000_000, redeemable: 0,
            taoValue: 3_000_000_000, availability: nil, primaryHotkey: Data(repeating: 1, count: 32)
        )
    }

    func calculate(_ portfolio: SubtensorPortfolio, _ histories: SubtensorPortfolioPriceHistories) -> SubtensorPortfolioValueSeries {
        SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio, histories: histories, currentTaoPrice: 417, precision: 9
        )
    }
}
