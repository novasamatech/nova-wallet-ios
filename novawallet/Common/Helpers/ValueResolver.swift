import Foundation

class ValueResolver<P1, P2, P3, P4, P5, V> {
    let resultClosure: (V) -> Void
    let resolver: (P1, P2, P3, P4, P5) -> V

    private var p1Store: UncertainStorage<P1>
    private var p2Store: UncertainStorage<P2>
    private var p3Store: UncertainStorage<P3>
    private var p4Store: UncertainStorage<P4>
    private var p5Store: UncertainStorage<P5>

    init(
        p1Store: UncertainStorage<P1> = .undefined,
        p2Store: UncertainStorage<P2> = .undefined,
        p3Store: UncertainStorage<P3> = .undefined,
        p4Store: UncertainStorage<P4> = .undefined,
        p5Store: UncertainStorage<P5> = .undefined,
        resolver: @escaping (P1, P2, P3, P4, P5) -> V,
        resultClosure: @escaping (V) -> Void
    ) {
        self.p1Store = p1Store
        self.p2Store = p2Store
        self.p3Store = p3Store
        self.p4Store = p4Store
        self.p5Store = p5Store
        self.resolver = resolver
        self.resultClosure = resultClosure
    }

    private func resolve() {
        guard
            case let .defined(param1) = p1Store,
            case let .defined(param2) = p2Store,
            case let .defined(param3) = p3Store,
            case let .defined(param4) = p4Store,
            case let .defined(param5) = p5Store else {
            return
        }

        let value = resolver(param1, param2, param3, param4, param5)

        resultClosure(value)
    }
}

extension ValueResolver {
    func apply(param1: P1) {
        p1Store = .defined(param1)

        resolve()
    }

    func apply(param2: P2) {
        p2Store = .defined(param2)

        resolve()
    }

    func apply(param3: P3) {
        p3Store = .defined(param3)

        resolve()
    }

    func apply(param4: P4) {
        p4Store = .defined(param4)

        resolve()
    }

    func apply(param5: P5) {
        p5Store = .defined(param5)

        resolve()
    }
}
