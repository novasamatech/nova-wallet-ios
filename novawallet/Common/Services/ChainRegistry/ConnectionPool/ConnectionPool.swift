import Foundation
import SubstrateSdk
import Foundation_iOS

protocol ConnectionPoolProtocol {
    func setupConnection(for chain: ChainModel) throws -> ChainConnection
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func subscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)
    func unsubscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)
    func getOneShotConnection(for chain: ChainModel) -> JSONRPCEngine?
    func deactivateConnection(for chainId: ChainModel.Id)
}

protocol ConnectionStateSubscription: AnyObject {
    func didReceive(
        state: WebSocketEngine.State,
        for chainId: ChainModel.Id
    )
    func didSwitchURL(
        _ connection: ChainConnection,
        newURL: URL,
        for chainId: ChainModel.Id
    )
}

extension ConnectionStateSubscription {
    func didSwitchURL(
        _: ChainConnection,
        newURL _: URL,
        for _: ChainModel.Id
    ) {}
}

class ConnectionPool {
    let connectionFactory: ConnectionFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol

    private var mutex = NSLock()

    private(set) var connections: [ChainModel.Id: WeakWrapper] = [:]
    private(set) var oneShotConnections: [ChainModel.Id: OneShotConnection] = [:]

    private(set) var stateSubscriptions: [ChainModel.Id: [WeakWrapper]] = [:]

    private func clearUnusedConnections() {
        connections = connections.filter { $0.value.target != nil }
    }

    init(connectionFactory: ConnectionFactoryProtocol, applicationHandler: ApplicationHandlerProtocol) {
        self.connectionFactory = connectionFactory
        self.applicationHandler = applicationHandler

        applicationHandler.delegate = self
    }
}

extension ConnectionPool: ConnectionPoolProtocol {
    func subscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let subscribers = stateSubscriptions[chainId], subscribers.contains(where: { $0.target === subscriber }) {
            return
        }

        var subscribers = stateSubscriptions[chainId] ?? []
        subscribers.append(WeakWrapper(target: subscriber))
        stateSubscriptions[chainId] = subscribers

        let connection = connections[chainId]?.target as? ChainConnection

        DispatchQueue.main.async {
            subscriber.didReceive(state: connection?.state ?? .notConnected(url: nil), for: chainId)
        }
    }

    func unsubscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let subscribers = stateSubscriptions[chainId]
        stateSubscriptions[chainId] = subscribers?.filter { $0.target !== subscriber }
    }

    func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearUnusedConnections()

        if let connection = connections[chain.chainId]?.target as? ChainConnection {
            connectionFactory.updateConnection(connection, chain: chain)

            if case .notConnected = connection.state {
                connection.connect()
            }

            return connection
        }

        let connection = try connectionFactory.createConnection(for: chain, delegate: self)
        connections[chain.chainId] = WeakWrapper(target: connection)

        return connection
    }

    func deactivateConnection(for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let optConnection = connections[chainId]?.target
        oneShotConnections[chainId] = nil

        clearUnusedConnections()

        if let connection = optConnection as? ChainConnection {
            connection.disconnect(true)
        }
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connections[chainId]?.target as? ChainConnection
    }

    func getOneShotConnection(for chain: ChainModel) -> JSONRPCEngine? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existingConnection = oneShotConnections[chain.chainId] {
            connectionFactory.updateOneShotConnection(existingConnection, chain: chain)

            return existingConnection
        }

        if let connection = try? connectionFactory.createOneShotConnection(for: chain) {
            oneShotConnections[chain.chainId] = connection

            return connection
        } else {
            return connections[chain.chainId]?.target as? JSONRPCEngine
        }
    }
}

extension ConnectionPool: WebSocketEngineDelegate {
    func webSocketDidSwitchURL(
        _ connection: AnyObject,
        newUrl: URL
    ) {
        processWebsocketChange(
            connection: connection,
            newState: nil,
            newUrl: newUrl
        )
    }

    func webSocketDidChangeState(
        _ connection: AnyObject,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        processWebsocketChange(
            connection: connection,
            newState: newState,
            newUrl: nil
        )
    }

    func processWebsocketChange(
        connection: AnyObject,
        newState: WebSocketEngine.State?,
        newUrl: URL?
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let allChainIds = connections.keys
        let maybeChainId = allChainIds.first(where: { connections[$0]?.target === connection })

        guard
            let chainId = maybeChainId,
            let chainConnection = connection as? ChainConnection
        else {
            return
        }

        let maybeSubscriptions = stateSubscriptions[chainId]?.compactMap { $0.target as? ConnectionStateSubscription }

        guard let subscriptions = maybeSubscriptions, !subscriptions.isEmpty else {
            return
        }

        DispatchQueue.main.async {
            if let newUrl {
                subscriptions.forEach {
                    $0.didSwitchURL(
                        chainConnection,
                        newURL: newUrl,
                        for: chainId
                    )
                }
            } else if let newState {
                subscriptions.forEach {
                    $0.didReceive(
                        state: newState,
                        for: chainId
                    )
                }
            }
        }
    }
}

extension ConnectionPool: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        connections.values.forEach { wrapper in
            guard let connection = wrapper.target as? ChainConnection else {
                return
            }

            connection.connect()
        }
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        connections.values.forEach { wrapper in
            guard let connection = wrapper.target as? ChainConnection else {
                return
            }

            connection.disconnect(true)
        }
    }
}
