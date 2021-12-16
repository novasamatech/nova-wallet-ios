import XCTest
@testable import novawallet
import Cuckoo
import SubstrateSdk
import SoraFoundation

class ConnectionPoolTests: XCTestCase {
    func testSetupCreatesNewConnections() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            stub(connectionFactory) { stub in
                stub.createConnection(for: any(), delegate: any()).then { _, _ in
                    MockConnection()
                }
            }

            let connectionPool = ConnectionPool(
                connectionFactory: connectionFactory,
                applicationHandler: ApplicationHandler()
            )

            // when

            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)

            let connections: [JSONRPCEngine] = try chainModels.reduce([]) { (allConnections, chain) in
                let connection = try connectionPool.setupConnection(for: chain)
                return allConnections + [connection]
            }

            // then

            let actualChainIds = Set(connectionPool.connections.keys)
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(connections.count, expectedChainIds.count)
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }

    func testSetupUpdatesExistingConnection() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            var urls: [URL] = []

            let setupConnection: () -> MockConnection = {
                let mockConnection = MockConnection()
                stub(mockConnection.autobalancing) { stub in
                    stub.changeUrls(any()).then { newUrls in
                        urls = newUrls
                    }

                    stub.urls.get.thenReturn(urls)
                }

                return mockConnection
            }

            stub(connectionFactory) { stub in
                stub.createConnection(for: any(), delegate: any()).then { _, _ in
                    setupConnection()
                }

                stub.updateConnection(any(), chain: any()).then { connection, chain in
                    connection.changeUrls(chain.nodes.map { $0.url })
                }
            }

            let connectionPool = ConnectionPool(
                connectionFactory: connectionFactory,
                applicationHandler: ApplicationHandler()
            )

            // when

            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)

            let newConnections: [MockConnection] = try chainModels.reduce(
                []
            ) { (allConnections, chain) in
                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
                    return allConnections + [connection]
                } else {
                    return allConnections
                }
            }
            
            let updatedConnections: [MockConnection] = try chainModels.reduce(
                []
            ) { (allConnections, chain) in
                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
                    return allConnections + [connection]
                } else {
                    return allConnections
                }
            }

            // then

            let actualChainIds = Set(connectionPool.connections.keys)
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(newConnections.count, updatedConnections.count)

            for index in 0..<newConnections.count {
                XCTAssertTrue(newConnections[index] === updatedConnections[index])
            }
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }
}
