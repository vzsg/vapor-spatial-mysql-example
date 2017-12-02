import Foundation
import Vapor
import Random

class LocationController: RouteCollection {
    let repository: LocationRepository
    let jsonEncoder: JSONEncoder

    init(repository: LocationRepository) {
        self.repository = repository
        jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .secondsSince1970
    }

    func build(_ builder: RouteBuilder) throws {
        builder.post("create") { req in
            guard let location: Location = try? req.decodeJSONBody() else {
                throw Abort.badRequest
            }

            let id = try self.repository.save(location)
            let res = Response(status: .created)
            res.headers[.location] = "/info/\(id)"
            return res
        }

        builder.post("seed") { req in
            let count = req.query?["count"]?.int ?? 1000

            guard count > 1 else {
                throw Abort.badRequest
            }

            let seedLocations = (1...count).map {
                Location(title: "Test Location \($0)",
                    longitude: OSRandom().makeDouble(min: -180, max: 180),
                    latitude: OSRandom().makeDouble(min: -90, max: 90))
            }

            try self.repository.saveAll(seedLocations)
            return Response(status: .noContent)
        }

        builder.get("near") { req in
            guard let lat = req.query?["lat"]?.double, let lng = req.query?["lng"]?.double else {
                throw Abort.badRequest
            }

            let range = req.query?["range"]?.double ?? 100
            let limit = max(1, min(1000, req.query?["limit"]?.int ?? 100))
            let result = try self.repository.findAllNear(longitude: lng,
                                                         latitude: lat,
                                                         rangeInMeters: range,
                                                         limit: limit)

            return try result.makeResponse()
        }

        builder.get("info/:id") { req in
            guard let id = try? req.parameters.next(UInt64.self) else {
                throw Abort.badRequest
            }

            guard let item = try self.repository.findById(id) else {
                throw Abort.notFound
            }

            return try item.makeResponse(using: self.jsonEncoder)
        }
    }
}
