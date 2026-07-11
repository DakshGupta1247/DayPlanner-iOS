# DayPlanner — App Overview

## What is DayPlanner?

DayPlanner is a personal iOS app that helps you plan and navigate a full day of visiting multiple places — like a smarter version of Apple Maps mixed with a daily itinerary planner.

Imagine you want to spend a Saturday visiting 4-5 places in your city — a museum, a café, a park, a market. Without an app like this, you'd have to:
- Manually figure out the best order to visit them
- Estimate how long travel takes between each place
- Try to remember what time you need to leave each stop
- Keep switching between Maps and your notes

DayPlanner solves all of that in one place.

---

## How the App Works — The Full Journey

Here's the complete flow from opening the app to finishing your day trip:

```
Open App → Onboarding → Home Screen → Plan Trip → Add Stops
    → Optimize Route → View Itinerary → Navigate → Trip History
```

---

## Feature 1 — Onboarding (First Launch Experience)

**What it does:**
When you open the app for the very first time, you see a 3-page welcome carousel that explains what the app does.

- Page 1: "Plan Your Day" — explains the trip planning concept
- Page 2: "Optimize Your Route" — explains the smart routing
- Page 3: "Navigate with Ease" — explains turn-by-turn navigation

At the bottom are Skip, Next, and Get Started buttons. Once you tap "Get Started", the onboarding never shows again — the app remembers you've seen it.

**Why it matters:**
First-time users immediately understand the app's purpose without having to figure it out themselves.

---

## Feature 2 — Home Screen (Your Daily Dashboard)

**What it does:**
The main screen you see every day. It greets you by name with a time-aware greeting:
- "Good morning, Daksh!" (before noon)
- "Good afternoon, Daksh!" (noon to 5pm)
- "Good evening, Daksh!" (5pm to 9pm)
- "Good night, Daksh!" (after 9pm)

It also shows today's date.

**Two states:**

1. **No trip planned** — shows a big "Plan Your Day" button with an illustration
2. **Trip exists** — shows a summary card with your trip name, stop count, total planned time, travel mode, and two buttons: "View Route" and "Edit Trip"

There's also a "Clear Trip" option if you want to start fresh.

**In the toolbar (top right):**
- Clock icon → Trip History (all your past trips)
- Gear icon → Settings

---

## Feature 3 — Trip Builder (Planning Your Stops)

**What it does:**
This is where you actually build your day trip. It opens as a sheet (slides up from the bottom).

**How it works:**
1. **Search for places** — Type any place name (e.g. "Starbucks", "Central Park", "MOMA") and the app searches using Apple Maps in real time
2. **See search results** — Each result shows the place name, address, and category icon (coffee cup for cafés, tree for parks, etc.)
3. **Tap to add a stop** — The place gets added to your stops list
4. **Set time at each stop** — Each stop shows how many minutes you plan to spend there (default 30 min, adjustable)
5. **Reorder stops** — Drag and drop stops to change the order
6. **Delete stops** — Swipe left on a stop to remove it
7. **See stops on a map** — A live map shows pins for all your added stops
8. **Choose travel mode** — Pick Driving, Walking, or Transit
9. **Confirm** — Tap "Confirm Trip" when you're happy with your stops

You need at least 2 stops to proceed.

---

## Feature 4 — Route Optimizer (Finding the Smartest Order)

**What it does:**
Once you confirm your trip, the app automatically figures out the most efficient order to visit your stops — so you don't waste time backtracking.

**How it works under the hood:**
1. Uses a "nearest-neighbor" algorithm — starts from your first stop, always goes to the closest unvisited stop next
2. Calls Apple's routing API (MKDirections) to get real road distances and travel times between each pair of stops
3. Draws the route as a blue line on a full-screen map

**What you see:**
- A full-screen map with a blue route line connecting all stops in order
- Numbered pins: green for your first stop, red for your last, blue for everything in between
- A bottom card showing:
  - Total distance (e.g. "12.4 km")
  - Total travel time (e.g. "1h 23m")
  - Number of stops
  - A list of stops in optimized order, each showing travel time + distance to the next stop
- Two buttons: "Itinerary" and "Start Trip"

**Refresh button:**
Top-right corner — recalculates the route if you want to try again.

---

## Feature 5 — Day Itinerary (Your Hour-by-Hour Schedule)

**What it does:**
Shows a beautiful vertical timeline of your entire day — exactly what time you'll arrive at each stop, how long you'll stay, and when you'll leave to drive to the next one.

**What you see:**
- A summary header with your trip name, date, start time, total duration, and stop count
- A vertical timeline with a coloured dot and connecting line for each stop
- Each stop card shows: name, address, arrival time, departure time, and how long you're spending there
- Between stops: a small connector showing "→ 12 min · 3.2 km drive"
- At the bottom: projected finish time

**What you can edit:**
- **Start time** — Tap the blue "Start 9:00 AM" button to change when your day begins. A wheel picker appears
- **Time at each stop** — Tap the "45 min" badge on any stop to change it. A slider appears (5 min to 4 hours) with quick-pick buttons (15m, 30m, 45m, 60m, 90m)
- All changes cascade automatically — if you spend more time at stop 2, all arrival times after it update instantly

---

## Feature 6 — Turn-by-Turn Navigation (Guided Stop-by-Step)

**What it does:**
Guides you through your trip one stop at a time, with in-app directions and an Apple Maps launcher.

**What you see:**
- A progress bar at the top — one segment per stop, green = visited, blue = current, gray = upcoming
- A mini map centred on your current destination
- A "Current Stop" card with the stop name and two buttons:
  - **Navigate** — opens Apple Maps with full GPS turn-by-turn directions to this stop
  - **Arrived** — marks this stop as done and moves to the next one
- A collapsible "Step-by-step directions" panel — tap to expand and see each maneuver (e.g. "Turn left onto Market St — 0.3 km")
- An "Up Next" list showing upcoming stops
- A "Visited" list showing completed stops (with strikethrough)
- A **"Start Live Navigation"** button to switch to real-time GPS tracking (FR9)

**When you've visited all stops:**
A "Trip Complete!" celebration screen appears with a checkmark and a "Back to Home" button.

---

## Feature 7 — Trip History (Your Past Trips)

**What it does:**
Every trip you plan is automatically saved to your phone. You can browse all your past trips, grouped by time period.

**What you see:**
- Trips grouped into three sections: **Today**, **This Week**, **Earlier**
- Each row shows: date badge, trip name, stop count, total planned time, and travel mode icon
- Swipe left on any trip to delete it
- Tap any trip to see the full detail view

**Trip Detail View:**
Shows the full `TripSummaryCard` (same as home screen) plus a numbered list of all stops with their addresses and planned durations.

**Auto-save:**
You never have to manually save. The moment you confirm a trip in the Trip Builder, it's saved automatically. If you close and reopen the app, today's trip loads automatically on the home screen.

---

## Feature 8 — Settings (Personalise Your App)

**What it does:**
A settings screen accessible from the gear icon on the Home screen.

**Four sections:**

### Profile
- Set your name — this appears in the "Good morning, NAME!" greeting
- Shows an avatar circle with your initials
- Name is saved instantly when you tap "Save"

### Trip Defaults
- Set your default travel mode (Driving / Walking / Transit)
- Pre-selected every time you start planning a new trip

### Appearance
- **System** — follows your iPhone's light/dark mode setting
- **Light** — always light mode
- **Dark** — always dark mode
- Changes apply to the entire app instantly, no restart needed

### About + Danger Zone
- Shows app version number
- "Reset Onboarding" button — shows the welcome screens again next time you open the app (useful for testing)

---

## Feature 9 — Live GPS Navigation (Real-Time Tracking)

**What it does:**
The most advanced feature. Turns DayPlanner into a real-time navigation app — like having a simplified Google Maps built in, but specifically for your planned day trip.

**What you see:**
- A full-screen map in 3D tilted view (like Apple Maps navigation mode)
- A **blue dot** showing your exact real-time location, moving as you move
- A **live blue route line** drawn from your current position to the next stop — updates every time you move 50+ metres
- Numbered pins for all your stops (green checkmark = visited, blue pulsing = current, gray = upcoming)
- A bottom card showing:
  - Current stop name and address
  - Live **ETA** that recalculates as you move (e.g. "12 min")
  - **Maps** button — opens Apple Maps
  - **Arrived** button — manually mark as arrived

**Smart auto-arrival:**
When you get within 50 metres of a stop, a green banner slides in from the top:
> "You've arrived! [Stop Name]" — [Mark Arrived button]

Tap "Mark Arrived" and the app automatically advances to the next stop and starts calculating the route to it.

**Permission:**
On first use, iOS asks: "Allow DayPlanner to use your location while using the app?" — you must tap Allow for this feature to work.

**Battery note:**
GPS tracking stops automatically when you leave the navigation screen, so it doesn't drain your battery in the background.

---

## Technical Summary (for the curious)

| Area | Technology used |
|---|---|
| UI framework | SwiftUI (Apple's modern UI framework) |
| Architecture | MVVM (Model-View-ViewModel) |
| Maps | MapKit (Apple's free mapping framework) |
| Routing | MKDirections (Apple's free routing API) |
| Place search | MKLocalSearch (Apple's free search API) |
| GPS tracking | CoreLocation + CLLocationManager |
| Data persistence | JSON files via FileManager |
| Settings storage | UserDefaults via @AppStorage |
| Async programming | Swift async/await |
| Minimum iOS | iOS 17+ |
| Cost of all APIs | Free — no paid third-party services |

---

## What Makes This App Different

1. **Everything is free** — no Google Maps API, no paid services, uses only Apple's built-in frameworks
2. **Offline-friendly** — once a trip is confirmed, the map data and route are cached
3. **Smart ordering** — the nearest-neighbor algorithm means you never waste time backtracking across a city
4. **Cascading itinerary** — change one stop's duration and every arrival time after it updates automatically
5. **Persistent** — your trip survives app restarts; history is saved automatically

---

*Built with SwiftUI + MapKit — iOS 17+*
