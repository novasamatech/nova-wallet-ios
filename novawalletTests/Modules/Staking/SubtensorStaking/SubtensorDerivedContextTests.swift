import Foundation
import NovaAuth
import Operation_iOS
import XCTest
@testable import novawallet

final class SubtensorDerivedContextTests: XCTestCase {
    private let accountId = Data(repeating: 7, count: 32)
    private let subnet = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)

    private struct Context {
        let config: AuthConfigProvider
        let auth: NovaAuthFacade
        let factory: BittensorApiOperationFactory
        let queue: OperationQueue
        let resolution: SubtensorMaxApyResolution
        let maxApy: SubtensorMaxApyProvider
        let costBasis: SubtensorCostBasisService
        let directory: SubtensorValidatorDirectoryService
    }

    override func setUp() {
        super.setUp()
        HostAuthURLProtocol.reset()
        HostAuthURLProtocol.business = Self.fixtureReply
    }

    override func tearDown() {
        HostAuthURLProtocol.reset()
        super.tearDown()
    }

    func testOriginChangeInvalidatesMemosAndSuspendedWrappers() throws {
        try assertInvalidation { context in
            context.config.publish(origin: "https://second.test", revision: 2)
        }
    }

    func testResetInvalidatesMemosAndSuspendedWrappers() throws {
        try assertInvalidation { try $0.auth.reset() }
    }

    func testLateMaxApyWalkCannotRestoreMemoOrDeliverOldSuccessAfterReset() throws {
        let context = try makeContext()
        _ = try run(context.auth.createEndpointWrapper())
        var lateCompletion: SubtensorMaxApyResolution.Completion?
        var results: [Result<Decimal?, Error>] = []
        let call = CancellationProbe()
        context.resolution.resolve(
            for: UUID(),
            generation: context.resolution.generation,
            startingWalkWith: { completion in
                lateCompletion = completion
                return call
            },
            completion: { results.append($0) }
        )

        try context.auth.reset()
        lateCompletion?(.success(Decimal(string: "0.99")))

        XCTAssertTrue(call.isCancelled)
        XCTAssertEqual(results.count, 1)
        XCTAssertThrowsError(try XCTUnwrap(results.first).get())
        XCTAssertNil(context.maxApy.cachedMaxApy().value)
    }

    func testResetDuringFirstMaxApyDeliveryRejectsRemainingWaiter() throws {
        let context = try makeContext()
        _ = try run(context.auth.createEndpointWrapper())
        var finishWalk: SubtensorMaxApyResolution.Completion?
        var results: [Result<Decimal?, Error>] = []
        let call = CancellationProbe()
        let completion: SubtensorMaxApyResolution.Completion = { result in
            results.append(result)
            if results.count == 1 {
                do {
                    try context.auth.reset()
                } catch {
                    XCTFail("Reset failed during waiter delivery")
                }
            }
        }
        for _ in 0 ..< 2 {
            context.resolution.resolve(
                for: UUID(),
                generation: context.resolution.generation,
                startingWalkWith: { finishWalk = $0; return call },
                completion: completion
            )
        }

        try XCTUnwrap(finishWalk)(.success(Decimal(string: "0.99")))

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(try results[0].get(), Decimal(string: "0.99"))
        XCTAssertThrowsError(try results[1].get())
        XCTAssertNil(context.maxApy.cachedMaxApy().value)
    }

    func testResetDuringFirstCostBasisDeliveryRejectsRemainingWaiter() throws {
        let context = try makeContext()
        _ = try run(context.auth.createEndpointWrapper())
        context.queue.isSuspended = true
        let wrappers = (0 ..< 2).map { _ in
            context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid)
        }
        var deliveries = 0
        let delivered = expectation(description: "both history waiters completed")
        delivered.expectedFulfillmentCount = 2
        let observations = wrappers.map { wrapper in
            wrapper.targetOperation.observe(\.isFinished, options: [.new]) { _, change in
                guard change.newValue == true else { return }
                deliveries += 1
                if deliveries == 1 {
                    do {
                        try context.auth.reset()
                    } catch {
                        XCTFail("Reset failed during waiter delivery")
                    }
                }
                delivered.fulfill()
            }
        }
        // Starting the outer operations synchronously registers both waiters before
        // the suspended history queue can produce its first page.
        wrappers.forEach { $0.targetOperation.start() }
        context.queue.isSuspended = false
        wait(for: [delivered], timeout: 10)

        let successes = wrappers.filter { (try? $0.targetOperation.extractNoCancellableResultData()) != nil }
        XCTAssertEqual(successes.count, 1)
        XCTAssertNil(context.costBasis.cachedCostBasis(for: accountId, netuid: subnet.netuid).value)
        withExtendedLifetime(observations) {}
    }

    func testOldCostBasisPageCannotRestoreHistoryAfterOriginChange() throws {
        let context = try makeContext()
        let requested = expectation(description: "history page in flight")
        let release = DispatchSemaphore(value: 0)
        HostAuthURLProtocol.business = { request in
            if request.url?.path.hasSuffix("/operations/search") == true {
                requested.fulfill()
                _ = release.wait(timeout: .now() + 10)
            }
            return Self.fixtureReply(request)
        }
        let wrapper = context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid)
        let completed = expectation(description: "old history waiter failed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        context.queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [requested], timeout: 10)

        context.config.publish(origin: "https://second.test", revision: 2)
        release.signal()
        wait(for: [completed], timeout: 10)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNil(context.costBasis.cachedCostBasis(for: accountId, netuid: subnet.netuid).value)
        XCTAssertThrowsError(try run(context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid)))
        XCTAssertNil(context.costBasis.cachedCostBasis(for: accountId, netuid: subnet.netuid).value)
    }

    func testDirectoryEnrichmentCannotRestoreOldListingAfterOriginChange() throws {
        let chain = HeldChainFactory()
        let context = try makeContext(chainFactory: chain)
        let enrichment = expectation(description: "listing received, waiting for enrichment")
        chain.onHold = { enrichment.fulfill() }
        let wrapper = context.directory.createDirectoryWrapper(for: subnet)
        let completed = expectation(description: "old directory failed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        context.queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [enrichment], timeout: 10)

        context.config.publish(origin: "https://second.test", revision: 2)
        try XCTUnwrap(chain.release)()
        wait(for: [completed], timeout: 10)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNil(context.directory.cachedDirectory(for: subnet).value)
    }

    func testDetailEnrichmentCannotDeliverOldMetadataAfterReset() throws {
        let chain = HeldChainFactory()
        let context = try makeContext(chainFactory: chain)
        _ = try run(context.directory.createDirectoryWrapper(for: subnet))
        let hotkey = try BittensorApiFixtureWorld.validator(.cinder).hotkey.toAccountId(
            using: .substrate(SubstrateConstants.genericAddressPrefix)
        )
        let enrichment = expectation(description: "detail waiting for enrichment")
        chain.onHold = { enrichment.fulfill() }
        let wrapper = context.directory.createDetailWrapper(for: hotkey, subnet: subnet)
        let completed = expectation(description: "old detail failed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        context.queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [enrichment], timeout: 10)

        try context.auth.reset()
        try XCTUnwrap(chain.release)()
        wait(for: [completed], timeout: 10)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNil(context.directory.cachedDirectory(for: subnet).value)
    }
}

private extension SubtensorDerivedContextTests {
    private func assertInvalidation(_ change: (Context) throws -> Void) throws {
        let context = try makeContext()
        XCTAssertNotNil(try run(context.maxApy.createMaxApyWrapper()))
        _ = try run(context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid))
        _ = try run(context.directory.createDirectoryWrapper(for: subnet))
        XCTAssertNotNil(context.maxApy.cachedMaxApy().value)
        XCTAssertNotNil(context.costBasis.cachedCostBasis(for: accountId, netuid: subnet.netuid).value)
        XCTAssertNotNil(context.directory.cachedDirectory(for: subnet).value)

        let suspendedMax = context.maxApy.createMaxApyWrapper()
        let suspendedCost = context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid)
        let suspendedDirectory = context.directory.createDirectoryWrapper(for: subnet)
        try change(context)
        let requestsBefore = HostAuthURLProtocol.requests.count

        XCTAssertNil(context.maxApy.cachedMaxApy().value)
        XCTAssertNil(context.costBasis.cachedCostBasis(for: accountId, netuid: subnet.netuid).value)
        XCTAssertNil(context.directory.cachedDirectory(for: subnet).value)
        XCTAssertThrowsError(try run(suspendedMax))
        XCTAssertThrowsError(try run(suspendedCost))
        XCTAssertThrowsError(try run(suspendedDirectory))
        XCTAssertThrowsError(try run(context.maxApy.createMaxApyWrapper()))
        XCTAssertThrowsError(try run(context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid)))
        XCTAssertThrowsError(try run(context.directory.createDirectoryWrapper(for: subnet)))
        XCTAssertEqual(HostAuthURLProtocol.requests.count, requestsBefore)

        _ = try run(context.factory.withIntent(.userInitiated).createSubnetsWrapper())
        XCTAssertNotNil(try run(context.maxApy.createMaxApyWrapper()))
        _ = try run(context.costBasis.createCostBasisWrapper(for: accountId, netuid: subnet.netuid))
        _ = try run(context.directory.createDirectoryWrapper(for: subnet))
        XCTAssertNotNil(context.maxApy.cachedMaxApy().value)
        XCTAssertNotNil(context.costBasis.cachedCostBasis(for: accountId, netuid: subnet.netuid).value)
        XCTAssertNotNil(context.directory.cachedDirectory(for: subnet).value)
    }

    private func makeContext(
        chainFactory: SubtensorValidatorChainOperationFactoryProtocol = BittensorFixtureChainSnapshot()
    ) throws -> Context {
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let config = AuthConfigProvider()
        let auth = NovaAuthFacade(
            configProvider: config,
            client: harness.client,
            activate: { try harness.client.activate(origin: $0) },
            reset: { try harness.client.reset() }
        )
        let queue = OperationQueue()
        let factory = BittensorApiOperationFactory(
            transport: BittensorAuthorizedTransport(provider: auth, operationQueue: OperationQueue()),
            cache: BittensorApiResponseCache(operationQueue: queue, logger: Logger.shared),
            logger: Logger.shared
        )
        let resolution = SubtensorMaxApyResolution()
        return Context(
            config: config,
            auth: auth,
            factory: factory,
            queue: queue,
            resolution: resolution,
            maxApy: SubtensorMaxApyProvider(
                recommendationService: SubtensorRecommendationService(
                    apiOperationFactory: factory, chainOperationFactory: chainFactory, operationQueue: queue
                ),
                apiOperationFactory: factory, resolution: resolution, operationQueue: queue,
                requestSpacing: 0, retryDelay: 0
            ),
            costBasis: SubtensorCostBasisService(
                apiOperationFactory: factory, operationQueue: queue, eventCenter: EventCenter(),
                walkSettings: .init(requestSpacing: 0, retryDelay: 0, maxPages: 10)
            ),
            directory: SubtensorValidatorDirectoryService(
                apiOperationFactory: factory, chainOperationFactory: chainFactory,
                cache: SubtensorValidatorDirectoryCache(), operationQueue: queue
            )
        )
    }

    func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "wrapper completed")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    static func fixtureReply(_ request: URLRequest) -> HostAuthURLProtocol.Reply {
        let path = request.url?.path ?? ""
        let parts = path.split(separator: "/")
        let query = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        let page = query.first { $0.name == "page" }.flatMap { $0.value.flatMap(Int.init) } ?? 1
        let route: BittensorApiFixtureRoute
        if path.hasSuffix("/operations/search") {
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            route = .operations(page: body?["page"] as? Int ?? 1)
        } else if path.hasSuffix("/recommendations/subnets") { route = .rankedSubnets }
        else if path.hasSuffix("/recommendations") { route = .recommendations }
        else if path.hasSuffix("/validators"), let netuid = UInt16(parts[parts.count - 2]) {
            route = .validators(netuid: netuid)
        } else if path.hasSuffix("/yields/alpha"), let netuid = UInt16(parts[parts.count - 3]) {
            route = .alphaYield(netuid: netuid, page: page, pageSize: 100)
        } else if path.hasSuffix("/yields/root") { route = .rootYield(page: page, pageSize: 100) }
        else { route = .subnets }
        let body = (try? JSONSerialization.data(withJSONObject: BittensorApiFixtureRouter.document(for: route))) ?? Data()
        return HostAuthURLProtocol.Reply(status: 200, headers: ["Cache-Control": "no-store"], body: body)
    }

    final class CancellationProbe: CancellableCall {
        var isCancelled = false
        func cancel() { isCancelled = true }
    }

    final class HeldChainFactory: SubtensorValidatorChainOperationFactoryProtocol {
        let fixture = BittensorFixtureChainSnapshot()
        var onHold: (() -> Void)?
        var release: (() -> Void)?

        func createChainSnapshotWrapper(
            for query: SubtensorValidatorChainQuery
        ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot> {
            let wrapper = fixture.createChainSnapshotWrapper(for: query)
            guard let onHold else { return wrapper }
            self.onHold = nil
            let held = AsyncClosureOperation<SubtensorValidatorChainSnapshot>(operationClosure: { [self] completion in
                release = { completion(Result { try wrapper.targetOperation.extractNoCancellableResultData() }) }
                onHold()
            }, cancelationClosure: {})
            held.addDependency(wrapper.targetOperation)
            return wrapper.insertingTail(operation: held)
        }

        func createIdentitiesWrapper(for hotkeys: [AccountId])
            -> CompoundOperationWrapper<[AccountId: SubtensorValidatorIdentity]> {
            fixture.createIdentitiesWrapper(for: hotkeys)
        }
    }
}
