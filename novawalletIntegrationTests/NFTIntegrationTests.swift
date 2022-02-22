import XCTest
@testable import novawallet
import RobinHood

class NFTIntegrationTests: XCTestCase {

    func testRMRKV1NftFetch() {
        let address = "HKtvjeZDzCTboD5tH2zbZ9w58LSKWSzhVoC1ppEjy46p5oA"

        do {
            let nfts = try fetchRMRKV1NFT(for: address)
            XCTAssertTrue(!nfts.isEmpty)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testRMRKV2BirdsNftFetch() {
        let address = "HKtvjeZDzCTboD5tH2zbZ9w58LSKWSzhVoC1ppEjy46p5oA"

        do {
            let nfts = try fetchRMRKV2BirdsNFT(for: address)
            XCTAssertTrue(!nfts.isEmpty)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testRMRKV2ItemsNftFetch() {
        let address = "HKtvjeZDzCTboD5tH2zbZ9w58LSKWSzhVoC1ppEjy46p5oA"

        do {
            let nfts = try fetchRMRKV2ItemsNFT(for: address)
            XCTAssertTrue(!nfts.isEmpty)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testIPFSMetadataV1Fetch() {
        let address = "HKtvjeZDzCTboD5tH2zbZ9w58LSKWSzhVoC1ppEjy46p5oA"

        do {
            let nfts = try fetchRMRKV1NFT(for: address).prefix(3)
            let metadataList: [RMRKNftMetadataV1] = try nfts.compactMap { nft in
                guard let metadata = nft.metadata else {
                    return nil
                }

                return try fetchMetadata(for: metadata)
            }

            XCTAssertEqual(nfts.count, metadataList.count)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testIPFSMetadataV2BirdsFetch() {
        let address = "HKtvjeZDzCTboD5tH2zbZ9w58LSKWSzhVoC1ppEjy46p5oA"

        do {
            let nfts = try fetchRMRKV2BirdsNFT(for: address).prefix(3)
            let metadataList: [RMRKNftMetadataV2] = try nfts.compactMap { nft in
                guard let metadata = nft.metadata else {
                    return nil
                }

                return try fetchMetadata(for: metadata)
            }

            XCTAssertEqual(nfts.count, metadataList.count)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testIPFSMetadataV2ItemsFetch() {
        let address = "HKtvjeZDzCTboD5tH2zbZ9w58LSKWSzhVoC1ppEjy46p5oA"

        do {
            let nfts = try fetchRMRKV2ItemsNFT(for: address).prefix(3)
            let metadataList: [RMRKNftMetadataV2] = try nfts.compactMap { nft in
                guard let metadata = nft.metadata else {
                    return nil
                }

                return try fetchMetadata(for: metadata)
            }

            XCTAssertEqual(nfts.count, metadataList.count)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func fetchRMRKV1NFT(for address: AccountAddress) throws -> [RMRKNftV1] {
        let operationFactory = RMRKV1OperationFactory()
        let operationQueue = OperationQueue()

        let operation = operationFactory.fetchNfts(for: address)
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    private func fetchMetadata<T: Decodable>(for urlString: String) throws -> T {
        guard let storage = DistributedUrlParser().parse(url: urlString) else {
            throw BaseOperationError.unexpectedDependentResult
        }

        let factory = DistributedStorageOperationFactory()
        let operation: BaseOperation<T> = factory.createOperation(for: storage)
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    private func fetchRMRKV2BirdsNFT(for address: AccountAddress) throws -> [RMRKNftV2] {
        let operationFactory = RMRKV2OperationFactory()
        let operationQueue = OperationQueue()

        let operation = operationFactory.fetchBirdNfts(for: address)
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    private func fetchRMRKV2ItemsNFT(for address: AccountAddress) throws -> [RMRKNftV2] {
        let operationFactory = RMRKV2OperationFactory()
        let operationQueue = OperationQueue()

        let operation = operationFactory.fetchItemNfts(for: address)
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }
}
