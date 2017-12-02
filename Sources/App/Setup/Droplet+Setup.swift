@_exported import Vapor
import MySQLProvider

extension Droplet {
    public func setup() throws {
        let database = try MySQLDriver.Driver(config: config)
        let repository = MySQLLocationRepository(driver: database)
        try repository.prepare()

        let controller = LocationController(repository: repository)
        try controller.build(router)
    }
}

