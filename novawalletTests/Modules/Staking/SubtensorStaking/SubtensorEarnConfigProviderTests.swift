import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import Operation_iOS

private final class SubtensorEarnConfigStubURLProtocol: URLProtocol {
    enum Reply {
        case payload(Data)
        case notFound
        case offline
    }

    static let scheme = "novaearnconfigstub"

    private static let lock = NSLock()
    private static var replies: [Reply] = []
    private static var delay: TimeInterval = 0
    private static var loads = 0

    static func reset(replies newReplies: [Reply], delay newDelay: TimeInterval = 0) {
        lock.lock()
        replies = newReplies
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
        let reply: Reply = Self.replies.isEmpty ? .offline : Self.replies.removeFirst()
        let delay = Self.delay
        Self.lock.unlock()

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let url = request.url else { return }

            switch reply {
            case let .payload(payload):
                respond(to: url, statusCode: 200, body: payload)
            case .notFound:
                respond(to: url, statusCode: 404, body: Data("404: Not Found".utf8))
            case .offline:
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            }
        }
    }

    override func stopLoading() {}

    private func respond(to url: URL, statusCode: Int, body: Data) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class SubtensorEarnConfigProviderTests: XCTestCase {
    private let configUrl = URL(string: "\(SubtensorEarnConfigStubURLProtocol.scheme)://nova-utils/earn_config.json")!
    private let bundledConfig = SubtensorEarnConfig(
        version: 1,
        entry: .init(enabled: true, newBadgeUntil: nil),
        headlineMaxAnnualRate: Decimal(string: "0.25"),
        preferredRootValidator: nil,
        logoBaseUrl: nil,
        subnets: [:],
        invalidEntries: []
    )
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
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.payload(makePayload(headlineRate: "0.40"))])

        let provider = makeProvider()

        let firstConfig = try fetch(from: provider)

        now = SubtensorEarnConfigProvider.cacheLifetime - 1

        let secondConfig = try fetch(from: provider)

        XCTAssertEqual(firstConfig.headlineMaxAnnualRate, Decimal(string: "0.40"))
        XCTAssertEqual(secondConfig, firstConfig)
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 1)
    }

    func testConcurrentCallersShareOneFetch() {
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.payload(makePayload(headlineRate: "0.40"))], delay: 0.2)

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
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.payload(makePayload(headlineRate: "0.40")), .offline])

        let provider = makeProvider()

        let firstConfig = try fetch(from: provider)

        now = SubtensorEarnConfigProvider.cacheLifetime

        let refreshedConfig = try fetch(from: provider)

        XCTAssertEqual(refreshedConfig, firstConfig)
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 2)
    }

    func testNotFoundServesTheBundledConfig() throws {
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.notFound])

        let config = try fetch(from: makeProvider())

        XCTAssertEqual(config, bundledConfig)
    }

    func testPublishedRemoteConfigReplacesTheBundledConfig() throws {
        let remotePayload = makePayload(headlineRate: nil)

        SubtensorEarnConfigStubURLProtocol.reset(replies: [.notFound, .payload(remotePayload)])

        let provider = makeProvider()

        let unpublishedConfig = try fetch(from: provider)
        let publishedConfig = try fetch(from: provider)

        XCTAssertEqual(unpublishedConfig, bundledConfig)
        XCTAssertEqual(publishedConfig, try JSONDecoder().decode(SubtensorEarnConfig.self, from: remotePayload))
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 2)
    }

    func testOfflineLaunchServesTheBundledConfigWithTheStoredRemoteEntry() throws {
        SubtensorEarnConfigStubURLProtocol.reset(replies: [
            .payload(makePayload(headlineRate: "0.40", entryEnabled: false)),
            .offline
        ])

        let settingsManager = InMemorySettingsManager()

        _ = try fetch(from: makeProvider(settingsManager: settingsManager))

        let offlineLaunchConfig = try fetch(from: makeProvider(settingsManager: settingsManager))

        let expected = SubtensorEarnConfig(
            version: 1,
            entry: .init(enabled: false, newBadgeUntil: nil),
            headlineMaxAnnualRate: Decimal(string: "0.25"),
            preferredRootValidator: nil,
            logoBaseUrl: nil,
            subnets: [:],
            invalidEntries: []
        )

        XCTAssertEqual(offlineLaunchConfig, expected)
    }

    func testNotFoundServesTheBundledConfigWhileTheProcessKeepsTheLastRemoteConfig() throws {
        let remotePayload = makePayload(headlineRate: "0.40", entryEnabled: false)

        SubtensorEarnConfigStubURLProtocol.reset(replies: [
            .payload(remotePayload),
            .notFound,
            .offline,
            .offline
        ])

        let settingsManager = InMemorySettingsManager()
        let provider = makeProvider(settingsManager: settingsManager)

        _ = try fetch(from: provider)

        now = SubtensorEarnConfigProvider.cacheLifetime

        let notFoundConfig = try fetch(from: provider)
        let offlineConfig = try fetch(from: provider)
        let offlineLaunchConfig = try fetch(from: makeProvider(settingsManager: settingsManager))

        XCTAssertEqual(notFoundConfig, bundledConfig)
        XCTAssertEqual(offlineConfig, try JSONDecoder().decode(SubtensorEarnConfig.self, from: remotePayload))
        XCTAssertEqual(offlineLaunchConfig, bundledConfig)
    }

    func testFailedBackgroundFetchWithoutCacheDoesNotServeTheBundledConfig() {
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.notFound])

        XCTAssertThrowsError(try fetch(from: makeProvider(), inBackground: true))
    }

    func testFailedBackgroundFetchIsNotRetriedUntilTheRetryIntervalPasses() throws {
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.offline, .payload(makePayload(headlineRate: "0.40"))])

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
        SubtensorEarnConfigStubURLProtocol.reset(replies: [.offline, .payload(makePayload(headlineRate: "0.40"))])

        let provider = makeProvider()

        XCTAssertThrowsError(try fetch(from: provider, inBackground: true))

        now = 1

        let interactiveConfig = try fetch(from: provider)

        XCTAssertEqual(interactiveConfig.headlineMaxAnnualRate, Decimal(string: "0.40"))
        XCTAssertEqual(SubtensorEarnConfigStubURLProtocol.loadCount, 2)
    }

    func testInvalidEntriesAreLoggedOnceAcrossRefreshes() throws {
        let invalidRootValidator = "141BZJmvZSXy3uiKoHmP1ZvUaq4b3ratkC5DE6GuU4K7je4W"

        SubtensorEarnConfigStubURLProtocol.reset(replies: [
            .payload(makePayload(headlineRate: "0.40", preferredRootValidator: invalidRootValidator)),
            .payload(makePayload(headlineRate: "0.35", preferredRootValidator: invalidRootValidator))
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

    func testBundledResourceDecodesWithEveryEntryValid() throws {
        let config = try XCTUnwrap(SubtensorEarnConfig.bundled)

        XCTAssertEqual(config.invalidEntries, [])
        XCTAssertTrue(config.subnets.values.allSatisfy { $0.registeredAt > 0 })
    }

    private func makeProvider(
        settingsManager: SettingsManagerProtocol = InMemorySettingsManager(),
        logger: LoggerProtocol = Logger.shared
    ) -> SubtensorEarnConfigProvider {
        SubtensorEarnConfigProvider(
            configURL: configUrl,
            bundledConfig: bundledConfig,
            entryStore: SubtensorEarnConfigEntryStore(settingsManager: settingsManager),
            operationQueue: OperationQueue(),
            logger: logger,
            timeProvider: { [unowned self] in now }
        )
    }

    private func makePayload(
        headlineRate: String?,
        preferredRootValidator: String? = nil,
        entryEnabled: Bool? = nil
    ) -> Data {
        let fields = [
            #""version": 1"#,
            entryEnabled.map { #""entry": {"enabled": \#($0)}"# },
            preferredRootValidator.map { #""preferredRootValidator": "\#($0)""# },
            headlineRate.map { #""headlineMaxAnnualRate": "\#($0)""# },
            #""subnets": {}"#
        ].compactMap { $0 }

        return Data("{\(fields.joined(separator: ", "))}".utf8)
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
