//
//  HomeView.swift
//  DayPlanner
//
//  Placeholder home screen — will be fully built in FR2.
//  For now it just shows the app name so we have something to land on
//  after onboarding completes.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("DayPlanner")
                .font(.largeTitle.bold())

            Text("Home screen — coming in FR2")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView()
}
