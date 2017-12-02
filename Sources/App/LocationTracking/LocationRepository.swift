import Foundation
import MySQLDriver

protocol LocationRepository {
    func findById(_ id: UInt64) throws -> Location?
    func findAllNear(longitude: Double, latitude: Double, rangeInMeters: Double, limit: Int) throws -> [LocationWithDistance]
    @discardableResult
    func save(_ location: Location) throws -> UInt64
    @discardableResult
    func saveAll(_ locations: [Location]) throws -> [UInt64]
}

class MySQLLocationRepository: LocationRepository {
    let driver: MySQLDriver.Driver

    init(driver: MySQLDriver.Driver) {
        self.driver = driver
    }

    func findById(_ id: UInt64) throws -> Location? {
        let result = try driver.raw("""
            SELECT
                id,
                title,
                X(g) AS longitude,
                Y(g) AS latitude,
                created_at,
                updated_at
            FROM locations
            WHERE id = ?
            """, [id])

        guard let item = result.array?.first else {
            return nil
        }

        return parseNode(item)
    }

    func findAllNear(longitude: Double, latitude: Double, rangeInMeters: Double, limit: Int) throws -> [LocationWithDistance] {
        let envLon1 = longitude + rangeInMeters / 1000.0 / abs(cos(latitude * Double.pi / 180.0) * 111.0)
        let envLat1 = latitude + rangeInMeters / 1000.0 / 111.0
        let envLon2 = longitude - rangeInMeters / 1000.0 / abs(cos(latitude * Double.pi / 180.0) * 111.0)
        let envLat2 = latitude - rangeInMeters / 1000.0 / 111.0

        let result = try driver.raw("""
            SELECT
                id,
                title,
                X(g) AS longitude,
                Y(g) AS latitude,
                created_at,
                updated_at,
                ST_DISTANCE_SPHERE(POINT(?, ?), g) AS distance
            FROM locations
            WHERE ST_CONTAINS(ST_MAKEENVELOPE(POINT(?, ?), POINT(?, ?)), g)
            ORDER BY distance LIMIT ?
        """, [longitude, latitude, envLon1, envLat1, envLon2, envLat2, limit])

        guard let array = result.array else {
            return []
        }

        return array.flatMap(parseNodeWithDistance)
    }

    func save(_ location: Location) throws -> UInt64 {
        let conn = try driver.makeConnection(.readWrite)

        // I have to admit, I just LOVE all the similarly named classes in Vapor 2
        return try save(location, on: conn as! Connection)
    }

    func saveAll(_ locations: [Location]) throws -> [UInt64] {
        return try driver.transaction { conn in
            var ids: [UInt64] = []

            // Side-effects in a map? Not in this neighborhood.
            try locations.forEach {
                ids.append(try self.save($0, on: conn as! Connection))
            }

            return ids
        }
    }

    private func save(_ location: Location, on connection: MySQLDriver.Connection) throws -> UInt64 {
        try connection.raw("""
            INSERT INTO locations (id, title, g) VALUES (?, ?, POINT(?, ?))
            ON DUPLICATE KEY UPDATE title=?, g=POINT(?, ?)
        """, [location.id, location.title, location.longitude, location.latitude,
              location.title, location.longitude, location.latitude])

        if let id = location.id {
            return id
        } else {
            let lastInsertId = try connection.raw("SELECT LAST_INSERT_ID() AS id")
            return try lastInsertId.get("0.id")
        }
    }

    func prepare() throws {
        try driver.raw("""
            CREATE TABLE IF NOT EXISTS locations (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                g GEOMETRY NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                SPATIAL INDEX(g))
            """)
    }

    private func parseNode(_ node: Node) -> Location? {
        guard let id: UInt64 = try? node.get("id"),
            let title: String = try? node.get("title"),
            let longitude: Double = try? node.get("longitude"),
            let latitude: Double = try? node.get("latitude"),
            let createdAt: Date = try? node.get("created_at"),
            let updatedAt: Date = try? node.get("updated_at") else {
                return nil
        }

        return Location(id: id,
                        title: title,
                        longitude: longitude,
                        latitude: latitude,
                        createdAt: createdAt,
                        updatedAt: updatedAt)
    }

    private func parseNodeWithDistance(_ node: Node) -> LocationWithDistance? {
        guard let location = parseNode(node) else {
            return nil
        }

        guard let distance: Double = try? node.get("distance") else {
            return nil
        }

        return LocationWithDistance(location: location, distance: distance)
    }
}
