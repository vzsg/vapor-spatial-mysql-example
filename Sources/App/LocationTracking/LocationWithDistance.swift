import Foundation

struct LocationWithDistance: Encodable {
    let location: Location
    let distance: Double

    enum CodingKeys: String, CodingKey {
        case distance
    }

    func encode(to encoder: Encoder) throws {
        try location.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distance, forKey: .distance)
    }
}
