import XCTest
import Cuckoo
import Operation_iOS
@testable import novawallet

final class OpenStakingUrlParsingServiceTests: XCTestCase {
    private let chain = ChainModelGenerator.generateChain(
        generatingAssets: 2,
        addressPrefix: 42,
        hasStaking: true
    )

    func testLinkWithoutQueryOpensDashboard() throws {
        let result = parse(url: URL(string: "novawallet://nova/open/staking")!, chains: [])

        guard case let .success(.staking(navigation)) = result else {
            return XCTFail("Unexpected result: \(result)")
        }

        XCTAssertNil(navigation)
    }

    func testLinkWithChainAndAssetOpensStakingForAsset() throws {
        let url = URL(string: "novawallet://nova/open/staking?chainId=\(chain.chainId)&assetId=1")!

        let result = parse(url: url, chains: [chain])

        guard case let .success(.staking(navigation)) = result else {
            return XCTFail("Unexpected result: \(result)")
        }

        XCTAssertEqual(navigation, StakingNavigation(chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: 1)))
    }

    func testAssetIdDefaultsToNativeAsset() throws {
        let url = URL(string: "novawallet://nova/open/staking?chainid=\(chain.chainId)")!

        let result = parse(url: url, chains: [chain])

        guard case let .success(.staking(navigation)) = result else {
            return XCTFail("Unexpected result: \(result)")
        }

        XCTAssertEqual(navigation?.chainAssetId, ChainAssetId(chainId: chain.chainId, assetId: 0))
    }

    func testUnknownChainFails() throws {
        let url = URL(string: "novawallet://nova/open/staking?chainId=\(KnowChainId.bittensor)")!

        let result = parse(url: url, chains: [chain])

        guard case .failure(.openStakingScreen(.chainNotFound)) = result else {
            return XCTFail("Unexpected result: \(result)")
        }
    }

    func testUnknownAssetFails() throws {
        let url = URL(string: "novawallet://nova/open/staking?chainId=\(chain.chainId)&assetId=7")!

        let result = parse(url: url, chains: [chain])

        guard case .failure(.openStakingScreen(.assetNotFound)) = result else {
            return XCTFail("Unexpected result: \(result)")
        }
    }

    func testAssetWithoutStakingFails() throws {
        let plainChain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: false
        )

        let url = URL(string: "novawallet://nova/open/staking?chainId=\(plainChain.chainId)")!

        let result = parse(url: url, chains: [plainChain])

        guard case .failure(.openStakingScreen(.stakingNotSupported)) = result else {
            return XCTFail("Unexpected result: \(result)")
        }
    }

    // MARK: - Private

    private func parse(
        url: URL,
        chains: [ChainModel]
    ) -> Result<UrlHandlingScreen, OpenScreenUrlParsingError> {
        let chainRegistry = MockChainRegistryProtocol()

        stub(chainRegistry) { stub in
            when(
                stub.chainsSubscribe(
                    any(),
                    runningInQueue: any(),
                    filterStrategy: any(),
                    updateClosure: any()
                )
            ).then { _, _, _, updateClosure in
                updateClosure(chains.map { DataProviderChange.insert(newItem: $0) })
            }

            when(stub.chainsUnsubscribe(any())).thenDoNothing()
        }

        let service = OpenStakingUrlParsingService(chainRegistry: chainRegistry)

        let expectation = XCTestExpectation()
        var parsingResult: Result<UrlHandlingScreen, OpenScreenUrlParsingError>?

        service.parse(url: url) { result in
            parsingResult = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        return parsingResult ?? .failure(.openStakingScreen(.chainNotFound))
    }
}
