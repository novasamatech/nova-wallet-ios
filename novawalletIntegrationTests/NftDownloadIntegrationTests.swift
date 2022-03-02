import XCTest
@testable import novawallet

class NftDownloadIntegrationTests: XCTestCase {
    func testNftResolveUrlAndCache() {
        // given

        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ipfs-test")
        let ipfsHash = "bafkreihzrh5edloxxefdky3kqg5bm4norx2gqnjau4iwsgwm5nubrtjr3a"
        let fileManager = FileManager.default
        let localCacheUrl = cachesURL.appendingPathComponent(ipfsHash)

        let nftDownloadService = NftFileDownloadService(
            cacheBasePath: cachesURL.path,
            fileRepository: FileRepository(),
            fileDownloadFactory: FileDownloadOperationFactory(),
            operationQueue: OperationQueue()
        )

        let expectation = XCTestExpectation()
        var requestResult: Result<URL?, Error>?

        // when

        _ = nftDownloadService.resolveImageUrl(for: ipfsHash, dispatchQueue: .main) { result in
            requestResult = result

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 20)

        // then

        guard case let .success(optUrl) = requestResult, let url = optUrl else {
            XCTFail("Unexpected result \(requestResult.debugDescription)")
            return
        }

        Logger.shared.info("Resolved url: \(url)")

        let fileExistsInCache = fileManager.fileExists(atPath: localCacheUrl.path)

        XCTAssertTrue(fileExistsInCache)
    }
}
