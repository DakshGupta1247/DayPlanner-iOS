//
//  PlanItem.swift
//  DayPlanner (PlanDay)
//
//  Union type for the home screen.
//  The home screen shows a mixed list of standalone Day Plans and multi-day Trips.
//  PlanItem lets us put both in the same [PlanItem] array.
//
//  Custom Codable: Swift enums with associated values need manual encoding
//  because JSON doesn't have a native "tagged union" concept.
//  We store a "type" field + a "payload" field — the type tells the decoder
//  which struct to decode the payload into.
//

import Foundation

enum PlanItem: Identifiable {
    case singleDay(DayPlan)
    case multiDayTrip(Trip)

    var id: UUID {
        switch self {
        case .singleDay(let d):    return d.id
        case .multiDayTrip(let t): return t.id
        }
    }

    var startDate: Date {
        switch self {
        case .singleDay(let d):    return d.date
        case .multiDayTrip(let t): return t.startDate
        }
    }

    var status: PlanStatus {
        switch self {
        case .singleDay(let d):    return d.status
        case .multiDayTrip(let t): return t.status
        }
    }
}

// MARK: - Codable

extension PlanItem: Codable {

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum ItemType: String, Codable { case singleDay, multiDayTrip }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .singleDay(let d):
            try c.encode(ItemType.singleDay, forKey: .type)
            try c.encode(d, forKey: .payload)
        case .multiDayTrip(let t):
            try c.encode(ItemType.multiDayTrip, forKey: .type)
            try c.encode(t, forKey: .payload)
        }
    }

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        let typ = try c.decode(ItemType.self, forKey: .type)
        switch typ {
        case .singleDay:
            self = .singleDay(try c.decode(DayPlan.self, forKey: .payload))
        case .multiDayTrip:
            self = .multiDayTrip(try c.decode(Trip.self, forKey: .payload))
        }
    }
}
