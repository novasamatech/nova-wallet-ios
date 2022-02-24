import XCTest
@testable import novawallet
import RobinHood

class NftSyncIntegrationTests: XCTestCase {

    func testUniquesSync() {
        let address = "Hn7GWG6eevwpYCJhG2SAWXo2H2PoMiMk4uPPS5pVtcE8Miz"

        performSyncTest(for: address, types: [.uniques])
    }

    func testRMRKV1Sync() {
        let address = "JEQCTc6gwgTPvsVD9CR1FsYEEEfYCV7EmixhCHaoDGR65By"

        performSyncTest(for: address, types: [.rmrkV1])
    }

    func testRMRKV2Sync() {
        let address = "EaVj8VBbNU29BVdJYnwTjakoh1wDpBAYp5e5hdcdvpEvEv9"

        performSyncTest(for: address, types: [.rmrkV2])
    }

    private func performSyncTest(for address: AccountAddress, types: Set<NftType>) {
        do {
            // given

            let storageFacade = SubstrateStorageTestFacade()
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

            let operationQueue = OperationQueue()
            let operationManager = OperationManager(operationQueue: operationQueue)

            let ownerId = try address.toAccountId()

            let wallet = MetaAccountModel(
                metaId: UUID().uuidString,
                name: "test",
                substrateAccountId: ownerId,
                substrateCryptoType: 0,
                substratePublicKey: ownerId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: []
            )

            var chains: [ChainModel] = []

            let chainsExpectation: XCTestExpectation = XCTestExpectation()

            chainRegistry.chainsSubscribe(self, runningInQueue: .global()) { changes in
                let newChains: [ChainModel] = changes.allChangedItems()

                if !newChains.isEmpty {
                    chains = newChains
                    chainsExpectation.fulfill()
                }
            }

            wait(for: [chainsExpectation], timeout: 10)

            // when

            let subscriptionFactory = NftLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                operationManager: operationManager,
                logger: Logger.shared,
                operationQueue: operationQueue
            )

            let provider = subscriptionFactory.getNftProvider(for: wallet, chains: chains)

            var nftsStore: [String: NftModel] = [:]
            let nftsExpectation = XCTestExpectation()

            let updateClosure: ([DataProviderChange<NftModel>]) -> Void = { changes in
                let newNfts: [NftModel] = changes.allChangedItems()

                nftsStore = newNfts.reduce(into: nftsStore) { store, nft in
                    store[nft.identifier] = nft
                }

                let fullfilled = types.allSatisfy { type in
                    nftsStore.values.contains { $0.type == type.rawValue }
                }

                if fullfilled {
                    nftsExpectation.fulfill()
                }
            }

            provider.addObserver(
                self,
                deliverOn: .global(),
                executing: updateClosure,
                failing: { error in
                    XCTFail("Unexpected error \(error)")
                    nftsExpectation.fulfill()
                })

            // then

            wait(for: [nftsExpectation], timeout: 10)

            provider.removeObserver(self)

        } catch {
            XCTFail("Unexpected message \(error)")
        }
    }
}
