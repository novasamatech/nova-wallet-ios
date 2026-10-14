import Foundation

#if DEBUG
    enum BittensorApiFixtureRoute: Equatable {
        case subnets
        case validators(netuid: UInt16)
        case rootYield(page: Int, pageSize: Int)
        case alphaYield(netuid: UInt16, page: Int, pageSize: Int)
        case operations(page: Int)
        case recommendations
        case rankedSubnets
    }

    enum BittensorApiFixtureRouter {
        static let templates: Set<String> = [
            "/subnets",
            "/subnets/{netuid}/validators",
            "/subnets/{netuid}/yields/alpha",
            "/operations/search",
            "/recommendations",
            "/recommendations/subnets"
        ]

        static let pageRange = 1 ... 100
        static let defaultPageSize = 100
        static let maxSubjectLength = 128

        static func route(for request: BittensorApiRequest, requestId: String) throws -> BittensorApiFixtureRoute {
            let template = normalized(request.pathTemplate)

            guard templates.contains(template) else {
                throw BittensorApiError.routeNotPublished
            }

            let invalid = BittensorApiError.invalidRequest(code: "invalid_request", requestId: requestId)
            let netuid = try pathNetuid(path: normalized(request.path), template: template, invalid: invalid)

            switch template {
            case "/subnets/{netuid}/yields/alpha":
                let paging = try pagination(of: request.queryItems, invalid: invalid)

                guard let netuid, netuid != 0 else { throw invalid }
                return .alphaYield(netuid: netuid, page: paging.page, pageSize: paging.pageSize)
            case "/operations/search":
                return .operations(page: try searchPage(of: request.queryItems, invalid: invalid))
            default:
                guard request.queryItems.isEmpty else {
                    throw invalid
                }

                return plainRoute(template: template, netuid: netuid)
            }
        }

        static func document(for route: BittensorApiFixtureRoute) -> [String: Any] {
            switch route {
            case .subnets:
                return BittensorApiFixtureDocuments.subnets()
            case let .validators(netuid):
                return BittensorApiFixtureDocuments.validators(netuid: netuid)
            case let .rootYield(page, pageSize):
                return BittensorApiFixtureDocuments.rootYield(page: page, pageSize: pageSize)
            case let .alphaYield(netuid, page, pageSize):
                return BittensorApiFixtureDocuments.alphaYield(netuid: netuid, page: page, pageSize: pageSize)
            case let .operations(page):
                return BittensorApiFixtureDocuments.operations(page: page)
            case .recommendations:
                return BittensorApiFixtureDocuments.recommendations()
            case .rankedSubnets:
                return BittensorApiFixtureDocuments.rankedSubnets()
            }
        }

        static func cacheControl(for route: BittensorApiFixtureRoute, document: [String: Any]) -> String {
            guard let maxAge = maxAge(for: route), allowsReuse(document) else {
                return "no-store"
            }

            return "public, max-age=\(maxAge), must-revalidate"
        }
    }

    private extension BittensorApiFixtureRouter {
        static func maxAge(for route: BittensorApiFixtureRoute) -> Int? {
            switch route {
            case .subnets, .validators:
                return 300
            case .rootYield, .alphaYield:
                return 1800
            case .recommendations, .rankedSubnets:
                return 21180
            case .operations:
                return nil
            }
        }

        static func allowsReuse(_ document: [String: Any]) -> Bool {
            let meta = document["meta"] as? [String: Any] ?? [:]
            let components = meta["components"] as? [String: [String: Any]] ?? [:]
            let generation = meta["generation"] as? [String: Any] ?? [:]
            let servedFrom = generation["servedFrom"] as? String

            return servedFrom != "MEMORY" && !components.values.contains(where: blocksReuse)
        }

        static func blocksReuse(_ component: [String: Any]) -> Bool {
            let isStale = component["freshness"] as? String == "STALE"
            let isUnavailable = component["availability"] as? String == "UNAVAILABLE"
            let isTemporary = component["availabilityReason"] as? String == "temporarily_unavailable"

            return isStale || (isUnavailable && isTemporary)
        }

        static func normalized(_ path: String) -> String {
            path.hasPrefix("/") ? path : "/" + path
        }

        static func plainRoute(template: String, netuid: UInt16?) -> BittensorApiFixtureRoute {
            switch template {
            case "/subnets/{netuid}/validators":
                return .validators(netuid: netuid ?? 0)
            case "/recommendations":
                return .recommendations
            case "/recommendations/subnets":
                return .rankedSubnets
            default:
                return .subnets
            }
        }

        static func pathNetuid(path: String, template: String, invalid: Error) throws -> UInt16? {
            let pathSegments = path.split(separator: "/", omittingEmptySubsequences: false)
            let templateSegments = template.split(separator: "/", omittingEmptySubsequences: false)

            guard pathSegments.count == templateSegments.count else {
                throw BittensorApiError.routeNotPublished
            }

            var netuid: UInt16?

            for (segment, templateSegment) in zip(pathSegments, templateSegments) {
                if templateSegment == "{netuid}" {
                    guard let value = canonicalInteger(String(segment)), value <= Int(UInt16.max) else {
                        throw invalid
                    }

                    netuid = UInt16(value)
                } else if segment != templateSegment {
                    throw BittensorApiError.routeNotPublished
                }
            }

            return netuid
        }

        static func pagination(of queryItems: [URLQueryItem], invalid: Error) throws -> (page: Int, pageSize: Int) {
            var values: [String: Int] = [:]

            for item in queryItems {
                guard
                    ["page", "pageSize"].contains(item.name),
                    values[item.name] == nil,
                    let value = item.value.flatMap(canonicalInteger),
                    pageRange.contains(value) else {
                    throw invalid
                }

                values[item.name] = value
            }

            return (values["page"] ?? 1, values["pageSize"] ?? defaultPageSize)
        }

        static func searchPage(of queryItems: [URLQueryItem], invalid: Error) throws -> Int {
            var values: [String: String] = [:]

            for item in queryItems {
                guard
                    ["accountSubject", "page"].contains(item.name),
                    values[item.name] == nil,
                    let value = item.value else {
                    throw invalid
                }

                values[item.name] = value
            }

            guard let subject = values["accountSubject"], isValidSubject(subject) else {
                throw invalid
            }

            guard let rawPage = values["page"] else {
                return 1
            }

            guard let page = canonicalInteger(rawPage), pageRange.contains(page) else {
                throw invalid
            }

            return page
        }

        static func isValidSubject(_ subject: String) -> Bool {
            let scalars = subject.unicodeScalars

            return (1 ... maxSubjectLength).contains(scalars.count) && scalars.allSatisfy { ("!" ... "~").contains($0) }
        }

        static func canonicalInteger(_ lexeme: String) -> Int? {
            guard
                (1 ... 6).contains(lexeme.count),
                lexeme.utf8.allSatisfy({ (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains($0) }),
                lexeme == "0" || !lexeme.hasPrefix("0") else {
                return nil
            }

            return Int(lexeme)
        }
    }
#endif
