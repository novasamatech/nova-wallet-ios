import XCTest
@testable import novawallet

final class SwipeGovSummaryTests: XCTestCase {
    let url = URL(string: "https://opengov-backend-dev.novasama-tech.org/not-secure/api/v1/referendum-summaries/list")!

    func testSummaryFetch() {
        do {
            let referendums: Set<ReferendumIdLocal> = [1139, 1130, 1141]

            let summaries = try performSummaryFetch(
                for: KnowChainId.polkadot,
                language: "ru",
                referendums: referendums
            )

            Logger.shared.info("Summaries: \(summaries)")

            XCTAssertEqual(Set(summaries.keys), referendums)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    private func performSummaryFetch(
        for chainId: ChainModel.Id,
        language: String,
        referendums: Set<ReferendumIdLocal>
    ) throws -> SwipeGovSummaryById {
        let factory = SwipeGovSummaryOperationFactory(url: url)
        let operationQueue = OperationQueue()

        let wrapper = factory.createFetchWrapper(
            for: chainId,
            languageCode: language,
            referendumIds: referendums
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
