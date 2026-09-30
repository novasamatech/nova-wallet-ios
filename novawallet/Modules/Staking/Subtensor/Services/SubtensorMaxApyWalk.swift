import Foundation
import Operation_iOS

final class SubtensorMaxApyWalk {
    typealias Completion = (Result<Decimal?, Error>) -> Void

    static let recommendedClasses: [SubtensorRecommendationClass] = [.stable, .balanced, .higherUpside]

    let recommendationService: SubtensorRecommendationServiceProtocol
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let requestSpacing: TimeInterval
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var completion: Completion?
    private var currentCall: CancellableCall?
    private var isCancelled = false
    private var pairs: [SubtensorRecommendedPair] = []
    private var targets: [Target] = []
    private var alphaPages: [BittensorApiResult<BittensorApi.AlphaYieldCollection>] = []
    private var nextPage = 1
    private var nextRequestAt: TimeInterval?
    private var rootYield: SubtensorReportedYield?
    private var alphaYields: [UInt16: SubtensorAlphaYields] = [:]

    init(
        recommendationService: SubtensorRecommendationServiceProtocol,
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        requestSpacing: TimeInterval,
        timeProvider: @escaping () -> TimeInterval,
        logger: LoggerProtocol
    ) {
        self.recommendationService = recommendationService
        self.apiOperationFactory = apiOperationFactory
        self.operationQueue = operationQueue
        self.requestSpacing = requestSpacing
        self.timeProvider = timeProvider
        self.logger = logger
    }

    func start(completion: @escaping Completion) {
        mutex.lock()

        self.completion = completion

        mutex.unlock()

        run(recommendationService.createVerifiedRecommendationsWrapper()) { [weak self] result, requestedAt in
            self?.handleRecommendations(result, requestedAt: requestedAt)
        }
    }
}

extension SubtensorMaxApyWalk: CancellableCall {
    func cancel() {
        mutex.lock()

        isCancelled = true
        completion = nil

        let call = currentCall
        currentCall = nil

        mutex.unlock()

        call?.cancel()
    }
}

private extension SubtensorMaxApyWalk {
    enum Target {
        case root
        case alpha(netuid: UInt16, hotkeys: Set<AccountId>)
    }

    static func targets(for pairs: [SubtensorRecommendedPair]) -> [Target] {
        let rootNetuid = SubtensorStakingPallet.rootNetuid
        let rootTargets: [Target] = pairs.contains { $0.netuid == rootNetuid } ? [.root] : []

        let hotkeysByNetuid = Dictionary(grouping: pairs.filter { $0.netuid != rootNetuid }, by: \.netuid)
            .mapValues { Set($0.map(\.hotkey)) }

        let alphaTargets = hotkeysByNetuid.sorted { $0.key < $1.key }.map { netuid, hotkeys in
            Target.alpha(netuid: netuid, hotkeys: hotkeys)
        }

        return rootTargets + alphaTargets
    }

    func run<T>(
        _ wrapper: CompoundOperationWrapper<T>,
        handler: @escaping (Result<T, Error>, TimeInterval) -> Void
    ) {
        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        currentCall = wrapper

        mutex.unlock()

        let requestedAt = timeProvider()

        execute(wrapper: wrapper, inOperationQueue: operationQueue, runningCallbackIn: nil) { result in
            handler(result, requestedAt)
        }
    }

    func handleRecommendations(
        _ result: Result<SubtensorVerifiedRecommendations, Error>,
        requestedAt: TimeInterval
    ) {
        switch result {
        case let .success(recommendations):
            let pairs = Self.recommendedClasses.flatMap { recommendations.classes[$0] ?? [] }

            mutex.lock()

            self.pairs = pairs
            targets = Self.targets(for: pairs)
            pace(afterReceivingAt: recommendations.generation.receivedAt, requestedAt: requestedAt)

            mutex.unlock()

            advance()
        case let .failure(error):
            finish(with: .failure(error))
        }
    }

    func advance() {
        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        guard let target = targets.first else {
            let maxApy = bestRate()

            mutex.unlock()

            finish(with: .success(maxApy))

            return
        }

        let page = nextPage
        let delay = (nextRequestAt ?? 0) - timeProvider()

        mutex.unlock()

        guard delay > 0 else {
            request(target, page: page)

            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.request(target, page: page)
        }
    }

    func request(_ target: Target, page: Int) {
        switch target {
        case .root:
            let wrapper = apiOperationFactory.createRootYieldWrapper(page: SubtensorYieldService.rootYieldPage)

            run(wrapper) { [weak self] result, requestedAt in
                self?.handleRootYield(result, requestedAt: requestedAt)
            }
        case let .alpha(netuid, hotkeys):
            let wrapper = apiOperationFactory.createAlphaYieldWrapper(netuid: netuid, page: page)

            run(wrapper) { [weak self] result, requestedAt in
                self?.handleAlphaPage(result, netuid: netuid, hotkeys: hotkeys, page: page, requestedAt: requestedAt)
            }
        }
    }

    func handleRootYield(
        _ result: Result<BittensorApiResult<BittensorApi.RootYieldCollection>, Error>,
        requestedAt: TimeInterval
    ) {
        mutex.lock()

        switch result {
        case let .success(page):
            rootYield = SubtensorYieldService.makeRootYield(from: page)
            pace(afterReceivingAt: page.receivedAt, requestedAt: requestedAt)
        case let .failure(error):
            logger.warning("Subtensor root yield unavailable for the max APY: \(error)")
            pace(afterReceivingAt: nil, requestedAt: requestedAt)
        }

        completeTarget()

        mutex.unlock()

        advance()
    }

    func handleAlphaPage(
        _ result: Result<BittensorApiResult<BittensorApi.AlphaYieldCollection>, Error>,
        netuid: UInt16,
        hotkeys: Set<AccountId>,
        page: Int,
        requestedAt: TimeInterval
    ) {
        mutex.lock()

        switch result {
        case let .success(pageResult):
            pace(afterReceivingAt: pageResult.receivedAt, requestedAt: requestedAt)
            alphaPages.append(pageResult)

            let next = pageResult.value.pageInfo.nextPage
            let pages = BittensorApiPages(pages: alphaPages, hasMorePages: next != nil)
            let yields = try? SubtensorYieldService.makeAlphaYields(netuid: netuid, pages: pages, logger: logger)

            let hasFoundHotkeys = yields.map { hotkeys.isSubset(of: $0.yields.keys) } ?? false

            if let next, next > page, alphaPages.count < SubtensorYieldService.alphaYieldPageLimit, !hasFoundHotkeys {
                nextPage = next
            } else {
                alphaYields[netuid] = yields
                completeTarget()
            }
        case let .failure(error):
            logger.warning("Subtensor alpha yields of netuid \(netuid) unavailable for the max APY: \(error)")
            pace(afterReceivingAt: nil, requestedAt: requestedAt)
            completeTarget()
        }

        mutex.unlock()

        advance()
    }

    func pace(afterReceivingAt receivedAt: TimeInterval?, requestedAt: TimeInterval) {
        if let receivedAt, receivedAt < requestedAt {
            return
        }

        nextRequestAt = timeProvider() + requestSpacing
    }

    func completeTarget() {
        if !targets.isEmpty {
            targets.removeFirst()
        }

        alphaPages = []
        nextPage = 1
    }

    func bestRate() -> Decimal? {
        pairs.compactMap { pair in
            guard pair.netuid != SubtensorStakingPallet.rootNetuid else {
                return rootYield?.annualRate
            }

            return alphaYields[pair.netuid]?.yields[pair.hotkey]?.annualRate
        }.max()
    }

    func finish(with result: Result<Decimal?, Error>) {
        mutex.lock()

        let completion = self.completion

        self.completion = nil
        currentCall = nil

        mutex.unlock()

        completion?(result)
    }
}
