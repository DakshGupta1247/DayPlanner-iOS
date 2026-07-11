//
//  PlaceSearchResultRow.swift
//  DayPlanner
//
//  A single row in the place search results list.
//  Shows the place name, category, and an "Add" button.
//
//  This is a "dumb" view — it receives data and fires a callback.
//  It has no idea what happens when the button is tapped.
//

import MapKit
import SwiftUI

struct PlaceSearchResultRow: View {

    // The MapKit result to display
    let mapItem: MKMapItem

    // Called when the user taps the + button — handled by TripBuilderView
    let onAdd: () -> Void

    // True if this place has already been added to the trip
    let isAdded: Bool

    var body: some View {
        HStack(spacing: 12) {

            // — Category icon —
            // MKMapItem has a pointOfInterestCategory we can map to an SF Symbol
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: categorySymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            // — Name + address —
            VStack(alignment: .leading, spacing: 2) {
                Text(mapItem.name ?? "Unknown Place")
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // — Add / Added button —
            Button(action: onAdd) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isAdded ? .green : .blue)
            }
            // Disable button if already added so user can't add duplicates
            .disabled(isAdded)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    /// City + state as a subtitle. Uses new addressRepresentations where available.
    private var subtitle: String {
        if let address = mapItem.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true) {
            return address
        }
        return legacySubtitle
    }

    // Pre-iOS 26 fallback: placemark is deprecated in iOS 26 but still works on older OS.
    private var legacySubtitle: String {
        let parts = [mapItem.placemark.thoroughfare,
                     mapItem.placemark.locality,
                     mapItem.placemark.administrativeArea].compactMap { $0 }
        return parts.isEmpty ? "No address available" : parts.joined(separator: ", ")
    }

    /// Maps MKPointOfInterestCategory to an SF Symbol name
    private var categorySymbol: String {
        guard let cat = mapItem.pointOfInterestCategory else { return "mappin" }
        switch cat {
        case .restaurant, .cafe, .bakery, .foodMarket: return "fork.knife"
        case .hotel:                                   return "bed.double.fill"
        case .museum, .theater, .movieTheater:         return "building.columns.fill"
        case .park, .nationalPark, .beach:             return "leaf.fill"
        case .hospital, .pharmacy:                     return "cross.fill"
        case .gasStation:                              return "fuelpump.fill"
        case .store:                                   return "bag.fill"
        case .school, .university, .library:           return "books.vertical.fill"
        case .airport:                                 return "airplane"
        case .publicTransport:                         return "tram.fill"
        default:                                       return "mappin.circle.fill"
        }
    }

    /// Maps category to an accent color
    private var categoryColor: Color {
        guard let cat = mapItem.pointOfInterestCategory else { return .blue }
        switch cat {
        case .restaurant, .cafe, .bakery, .foodMarket: return .orange
        case .park, .nationalPark, .beach:             return .green
        case .hospital, .pharmacy:                     return .red
        case .museum, .theater, .movieTheater:         return .purple
        default:                                       return .blue
        }
    }
}
