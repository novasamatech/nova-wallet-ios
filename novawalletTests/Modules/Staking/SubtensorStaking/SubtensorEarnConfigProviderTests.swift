import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

private final class SubtensorEarnConfigStubURLProtocol: URLProtocol {
    static let scheme = "novaearnconfigstub"

    private static let lock = NSLock()
    private static var payloads: [Data?] = []
    private static var delay: TimeInterval = 0
    private static var loads = 0

    static func reset(payloads newPayloads: [Data?], delay newDelay: TimeInterval = 0) {
        lock.lock()
        payloads = newPayloads
        delay = newDelay
        loads = 0
        lock.unlock()
    }

    static var loadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return loads
    }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.scheme == scheme }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.loads += 1
        let payload: Data? = Self.payloads.isEmpty ? nil : Self.payloads.removeFirst()
        let delay = Self.delay
        Self.lock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let url = request.url else { return }

            guard let payload else {
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: payload)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

final class SubtensorEarnConfigProviderTests: XCTestCase {
    private let configUrl = URL(string: "\(SubtensorEarnConfigStubURLProtocol.scheme)://nova-utils/earn_config.json")!
    private var now: TimeInterval = 0

    override func setUp() {
        super.setUp()
        now = 0
        XCTAssertTrue(URLProtocol.registerClass(SubtensorEarnConfigStubURLProtocol.self))
    }

    override func tearDown() {
        URLProtocol.unregisterClass(SubtensorEarnConfigStubURLProtocol.self)
        super.tearDown()
    }

    func testConfigIsFetchedOnceAndServedFromCacheWithinThirtyMinutes() throws {
        SubtensorEarnConfigStubURLProtocol.reset(payloads: [makePayload(headlineRate: "0.40")])

        let provider = makeProvider()

        let firstConfig = try fetch(from: provider)

        now = SubtensorEarnConfigProvider.cacheLifetime - 1

        let secondConfig = try fetch(from: provider)

        XCTAssertEqual(firstConfig.headlineMaxAnnualRate, Decimal(string: "0.40"))
        XCTAssertEqual(secondConfig, firstConfig)
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 1)
    }

    func testConcurrentCallersShareOneFetch() {
        SubtensorEarnConfigStubURLProtocol.reset(payloads: [makePayload(headlineRate: "0.40")], delay: 0.2)

        let provider = makeProvider()
        let wrappers = [provider.createConfigWrapper(), provider.createConfigWrapper()]

        run(wrappers)

        for wrapper in wrappers {
            XCTAssertEqual(
                try wrapper.targetOperation.extractNoCancellableResultData().headlineMaxAnnualRate,
                Decimal(string: "0.40")
            )
        }

        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 1)
    }

    func testFailedRefreshServesTheLastGoodConfig() throws {
        SubtensorEarnConfigStubURLProtocol.reset(payloads: [makePayload(headlineRate: "0.40"), nil])

        let provider = makeProvider()

        let firstConfig = try fetch(from: provider)

        now = SubtensorEarnConfigProvider.cacheLifetime

        let refreshedConfig = try fetch(from: provider)

        XCTAssertEqual(refreshedConfig, firstConfig)
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 2)
    }

    func testFailedBackgroundFetchIsNotRetriedUntilTheRetryIntervalPasses() throws {
        SubtensorEarnConfigStubURLProtocol.reset(payloads: [nil, makePayload(headlineRate: "0.40")])

        let provider = makeProvider()

        XCTAssertThrowsError(try fetch(from: provider, inBackground: true))

        now = SubtensorEarnConfigProvider.failureRetryInterval - 1

        XCTAssertThrowsError(try fetch(from: provider, inBackground: true))
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 1)

        now = SubtensorEarnConfigProvider.failureRetryInterval

        let recoveredConfig = try fetch(from: provider, inBackground: true)

        XCTAssertEqual(recoveredConfig.headlineMaxAnnualRate, Decimal(string: "0.40"))
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 2)
    }

    func testFailedBackgroundFetchDoesNotHoldTheNextInteractiveFetch() throws {
        SubtensorEarnConfigStubURLProtocol.reset(payloads: [nil, makePayload(headlineRate: "0.40")])

        let provider = makeProvider()

        XCTAssertThrowsError(try fetch(from: provider, inBackground: true))

        now = 1

        let interactiveConfig = try fetch(from: provider)

        XCTAssertEqual(interactiveConfig.headlineMaxAnnualRate, Decimal(string: "0.40"))
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 2)
    }

    func testInvalidEntriesAreLoggedOnceAcrossRefreshes() throws {
        let invalidRootValidator = "141BZJmvZSXy3uiKoHmP1ZvUaq4b3ratkC5DE6GuU4K7je4W"

        SubtensorEarnConfigStubURLProtocol.reset(payloads: [
            makePayload(headlineRate: "0.40", preferredRootValidator: invalidRootValidator),
            makePayload(headlineRate: "0.35", preferredRootValidator: invalidRootValidator)
        ])

        let logger = MockLoggerProtocol()
        logger.enableDefaultImplementation(Logger.shared)

        let provider = makeProvider(logger: logger)

        _ = try fetch(from: provider)

        now = SubtensorEarnConfigProvider.cacheLifetime

        let refreshedConfig = try fetch(from: provider)

        XCTAssertEqual(refreshedConfig.headlineMaxAnnualRate, Decimal(string: "0.35"))
        verify(logger, times(1)).warning(
            message: "Subtensor Earn config entry ignored: preferredRootValidator",
            file: any(),
            function: any(),
            line: any()
        )
    }

    func testBundledFixtureDecodesWithEveryEntryValid() throws {
        let config = try JSONDecoder().decode(
            SubtensorEarnConfig.self,
            from: Data(SubtensorEarnConfigProvider.fixtureJSON.utf8)
        )

        let subnetEntry = config.subnetEntry(for: SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295))

        XCTAssertEqual(config.invalidEntries, [])
        XCTAssertNotNil(config.preferredRootValidator)
        XCTAssertNotNil(subnetEntry?.preferredValidator)
    }

    private func makeProvider(logger: LoggerProtocol = Logger.shared) -> SubtensorEarnConfigProvider {
        SubtensorEarnConfigProvider(
            configURL: configUrl,
            operationQueue: OperationQueue(),
            logger: logger,
            timeProvider: { [unowned self] in now }
        )
    }

    private func makePayload(headlineRate: String, preferredRootValidator: String? = nil) -> Data {
        let rootValidatorEntry = preferredRootValidator.map { #""preferredRootValidator": "\#($0)","# } ?? ""

        return Data(
            #"{"version": 1, \#(rootValidatorEntry) "headlineMaxAnnualRate": "\#(headlineRate)", "subnets": {}}"#.utf8
        )
    }

    private func run(_ wrappers: [CompoundOperationWrapper<SubtensorEarnConfig>]) {
        let completed = expectation(description: "Earn config resolved")
        completed.expectedFulfillmentCount = wrappers.count

        wrappers.forEach { wrapper in
            wrapper.targetOperation.completionBlock = { completed.fulfill() }
        }

        OperationQueue().addOperations(wrappers.flatMap(\.allOperations), waitUntilFinished: false)

        wait(for: [completed], timeout: 10)
    }

    private func fetch(
        from provider: SubtensorEarnConfigProvider,
        inBackground: Bool = false
    ) throws -> SubtensorEarnConfig {
        let wrapper = inBackground ? provider.createBackgroundConfigWrapper() : provider.createConfigWrapper()

        run([wrapper])

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
