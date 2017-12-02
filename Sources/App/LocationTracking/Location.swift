import Foundation

struct Location: Codable {
    let id: UInt64?
    let title: String
    let longitude: Double
    let latitude: Double
    let createdAt: Date?
    let updatedAt: Date?

    init(id: UInt64? = nil,
         title: String,
         longitude: Double,
         latitude: Double,
         createdAt: Date? = nil,
         updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.longitude = longitude
        self.latitude = latitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
