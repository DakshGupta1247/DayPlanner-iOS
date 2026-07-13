//
//  GPXParser.swift
//  DayPlanner
//
//  Parses a .gpx file from Bundle.main into an array of CLLocation values,
//  sorted by timestamp ascending. Uses only Foundation's XMLParser — no
//  third-party libraries.
//

import CoreLocation
import Foundation

struct GPXParser {

    // MARK: - Public API

    /// Parses `fileName.gpx` from the main bundle asynchronously.
    /// Returns an empty array if the file is missing or unparseable.
    static func parse(fileName: String) async -> [CLLocation] {
        await Task.detached(priority: .utility) {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "gpx"),
                  let data = try? Data(contentsOf: url)
            else { return [] }

            let handler = GPXHandler()
            let parser = XMLParser(data: data)
            parser.delegate = handler
            parser.parse()
            return handler.locations.sorted { $0.timestamp < $1.timestamp }
        }.value
    }
}

// MARK: - Private XMLParserDelegate

private final class GPXHandler: NSObject, XMLParserDelegate {

    private(set) var locations: [CLLocation] = []

    // State machine for the current <trkpt>
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var insideEle = false
    private var insideTime = false
    private var charBuffer = ""

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement element: String,
                namespaceURI: String?,
                qualifiedName: String?,
                attributes: [String: String]) {
        charBuffer = ""
        switch element {
        case "trkpt":
            currentLat  = attributes["lat"].flatMap { Double($0) }
            currentLon  = attributes["lon"].flatMap { Double($0) }
            currentEle  = nil
            currentTime = nil
        case "ele":
            insideEle   = true
        case "time":
            insideTime  = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        charBuffer += string
    }

    func parser(_ parser: XMLParser,
                didEndElement element: String,
                namespaceURI: String?,
                qualifiedName: String?) {
        switch element {
        case "ele":
            currentEle  = Double(charBuffer.trimmingCharacters(in: .whitespaces))
            insideEle   = false
        case "time":
            currentTime = isoFormatter.date(from: charBuffer.trimmingCharacters(in: .whitespaces))
            insideTime  = false
        case "trkpt":
            guard let lat  = currentLat,
                  let lon  = currentLon,
                  let time = currentTime
            else { break }

            let coord     = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let altitude  = currentEle ?? 0.0
            let location  = CLLocation(
                coordinate:         coord,
                altitude:           altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy:   5.0,
                timestamp:          time
            )
            locations.append(location)
        default:
            break
        }
        charBuffer = ""
    }
}
