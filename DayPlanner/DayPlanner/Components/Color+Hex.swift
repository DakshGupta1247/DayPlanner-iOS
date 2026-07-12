//
//  Color+Hex.swift
//  DayPlanner (PlanDay)
//
//  Parses a CSS hex string like "#3B82F6" into a SwiftUI Color.
//  Implemented as a static func (not an init) to avoid conflicts with
//  the SwiftUI Color(String, bundle:) and Color(hex: Int) initialisers.
//

import SwiftUI

extension Color {
    static func hex(_ hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
