# PlanDay — App Overview

## What is PlanDay?

PlanDay is a personal iOS app that helps you plan and navigate a full day of visiting multiple places — like a smarter version of Apple Maps mixed with a daily itinerary planner.

Imagine you want to spend a Saturday visiting 4–5 places in your city — a museum, a café, a park, a market. Without an app like this, you'd have to:
- Manually figure out the best order to visit them
- Estimate how long travel takes between each place
- Try to remember what time you need to leave each stop
- Keep switching between Maps and your notes

PlanDay solves all of that in one place.

---

## How the App Works — The Full Journey

```
Open App → Splash Screen → Profile Selection (or Profile Creation on first launch)
  → Home Screen → Plan Trip → Add Stops → Optimize Route
  → View Itinerary → Navigate → Trip History
```

---

## Feature 1 — Splash & Welcome Screen

**What it does:**
Every time you open the app, a dark blue splash screen appears for ~2.5 seconds with the PlanDay logo, the app name, and a tagline — then automatically advances.

- Logo scales up from 80% → 100% (easeOut animation)
- Tagline "Your Journey Starts Here ✈️" fades in at 0.8s
- Subtitle "Plan smarter. Travel better. Live fully." fades in shortly after
- On first ever launch: advances to Welcome Screen then Profile Creation
- On returning launches: advances to Profile Selection

The Welcome Screen shows the app heading "Plan Your Perfect Day" and a "Get Started →" button.

---

## Feature 2 — Profile System

**What it does:**
Supports up to 5 separate user profiles, each with their own name, SF Symbol avatar, accent color, and completely isolated trip history. Similar to Netflix's "Who's watching?" screen.

**First launch:**
A Profile Creation screen asks for:
- Your name (text field, required before proceeding)
- Avatar (8 SF Symbol options: person, star, heart, bolt, leaf, flame, moon, airplane)
- Accent color (8 colors)
Live preview circle updates as you pick. "Let's Go →" button disabled until name entered.

**Every launch after:**
A Netflix-style 2-column grid shows all profiles. Tap to select → go to Home.
- "+ Add Profile" cell at end of grid (hidden when at 5 profiles)
- "Manage Profiles" button → rename/delete sheet

**Why profiles?**
Each profile has completely isolated data. Switching profiles instantly shows that person's plans. Great for sharing a device (family members, travel companions).

---

## Feature 3 — Onboarding (First Launch Carousel)

**What it does:**
After creating their first profile, new users see a 3-page welcome carousel explaining the app. Never shown again after completion (unless "Reset Onboarding" is tapped in Settings).

- Page 1: "Plan Your Day" — trip planning concept
- Page 2: "Optimize Your Route" — smart routing
- Page 3: "Navigate with Ease" — turn-by-turn navigation

---

## Feature 4 — Home Screen (Your Daily Dashboard)

**What it does:**
The main screen you see every day. Greets you by name with a time-aware greeting ("Good morning", "Good afternoon", "Good evening", "Good night") and today's date.

**Two sections:**
1. **Today's Focus** — shows any plan with today's date in a highlighted card
2. **All Plans** — all saved plans sorted newest-first

**Plan cards:**
- *Day Plan card*: stop count, planned duration, travel mode, "View Route" button
- *Trip card*: emoji, trip name, days count, total stops, travel mode, "View Trip" button

**Empty state:**
When no plans exist: large map icon, "No Plans Yet" heading, blue "Create Your First Plan" button.

**FAB (Floating Action Button):**
Blue + button bottom-right. Tap to expand two options: "Plan a Day" and "Plan a Trip".

**Swipe actions:**
Swipe left on any card → Edit (blue) + Delete (red) buttons.

---

## Feature 5 — Day Plan Builder

**What it does:**
A sheet for creating a single-day plan. Search for places, add stops, set durations, pick travel mode.

1. Type a place name → real-time search results (powered by Apple Maps MKLocalSearch)
2. Tap a result → added to your stop list
3. Each stop shows a tappable duration badge ("30 min") → opens a slider picker
4. See all stops on a live map preview
5. Choose travel mode (Driving / Walking / Transit)
6. Tap "Save Plan" to confirm

Minimum 2 stops required. Edit mode pre-fills all fields from existing plan.

---

## Feature 6 — Trip Builder (Multi-Day)

**What it does:**
A 2-step sheet for planning a multi-day trip (up to 7 days).

**Step 1 — Trip Info:**
- Trip name, emoji (12 options), cover color (8 colors)
- Start date, number of days (1–7), travel mode

**Step 2 — Add Stops:**
- Day tab bar at top (if >1 day) — switches between Day 1, Day 2...
- Search + map + stop list per day
- Each day must have at least one stop to proceed

---

## Feature 7 — Route Optimizer (Finding the Smartest Order)

**What it does:**
Automatically figures out the most efficient order to visit your stops — so you don't waste time backtracking.

**How it works:**
1. Uses your current GPS location as the starting point (Stop #1 = closest stop to you)
2. Nearest-neighbour algorithm with binary min-heap (O(n log n) efficiency)
3. Calls Apple's MKDirections to get real road distances, travel times, and route polylines
4. Draws the route as a blue line on a full-screen map

**What you see:**
- Full-screen map with numbered pins (green = first, red = last, blue = middle)
- Bottom card: total distance, travel time, stop count
- Ordered stop list with travel time to next stop
- **Edit button** → drag-to-reorder mode

**GPS unavailable?**
If location permission is denied, a banner appears: "Using first added stop as start (location access unavailable)"

---

## Feature 8 — Drag-to-Reorder Route

**What it does:**
Manually rearrange stops in the route by dragging, then recalculate with your custom order.

**How to use:**
1. Tap "Edit" on the route screen
2. Drag the ≡ handle on any middle stop up or down
3. First and last stops are locked (🔒) — only middle stops can be reordered
4. "Recalculate Route" button turns blue once you've made a change
5. Tap to recalculate — app re-fetches travel times for your new sequence
6. Success toast appears: "Route updated based on your preferences"

**Cancel:**
Tap Cancel → if you've made changes, "Discard Changes?" confirmation appears.

---

## Feature 9 — Day Itinerary (Hour-by-Hour Schedule)

**What it does:**
A vertical timeline of your day — exact arrival and departure times for every stop, cascading automatically.

**What you see:**
- Summary header: trip name, date, start time, total duration, stop count
- Timeline rows: coloured dot + connecting line + stop card
- Each stop card: name, address, arrival–departure time range, duration badge
- Between stops: "→ 12 min · 3.2 km drive"
- Footer: projected finish time

**What you can edit:**
- **Start time** — tap "Start 9:00 AM" → wheel time picker
- **Duration at each stop** — tap the "45 min" badge → slider (5–240 min) + quick presets

All changes cascade: edit stop 2's duration → every arrival time after it updates instantly.

---

## Feature 10 — Stop Duration Editor

**What it does:**
Anywhere you see a "X min" badge on a stop — tap it to open a half-height sheet and change the duration.

- Slider: 5 min to 240 min, step of 5
- Quick preset buttons: 15m, 30m, 45m, 60m, 90m
- Available in: Day Plan Builder, Trip Builder, and Day Itinerary

---

## Feature 11 — Turn-by-Turn Navigation (Guided Stop-by-Step)

**What it does:**
Guides you through your trip one stop at a time with in-app directions and an Apple Maps launcher.

- Progress bar at top — green = visited, blue = current, gray = upcoming
- Mini map centred on current destination
- "Navigate" → opens Apple Maps with full GPS directions
- "Arrived" → marks stop done, moves to next
- Expandable step-by-step directions panel (e.g. "Turn left onto Market St — 0.3 km")
- "Up Next" list of upcoming stops
- Trip Complete! celebration when all stops visited

---

## Feature 12 — Live GPS Navigation

**What it does:**
Real-time GPS tracking with a live route line from your current position to the next stop.

- 3D tilted map view (like Apple Maps navigation)
- Blue dot showing your exact location, following your movement
- Live route polyline updates as you move (debounced, non-blocking)
- Live ETA (minutes remaining + projected arrival time) recalculating as you move
- Progress bar: shows "Stop X of Y" label + "N completed" count
- Stop card shows "NEXT DESTINATION" with stop name, address, ETA
- Auto-arrival detection: when within 100m of a stop, "You've arrived!" banner slides in
- Tap "Mark Arrived" → destination toast ("Next: India Gate") slides in, stop card updates
- Day Complete screen: confetti + stats + full visited stops list when all stops done

**Simulator/Demo mode:** In DEBUG builds, a GPX file replays a Delhi route automatically — no real GPS needed. Tap "Load Delhi Demo" on the Home screen to try it.

**GPS permission:** iOS asks "Allow PlanDay to use your location" on first use.

**Battery:** GPS tracking stops automatically when you leave this screen.

---

## Feature 13 — Trip History

**What it does:**
Every plan is automatically saved. Browse all past trips grouped by time period.

- Three groups: **Today**, **This Week**, **Earlier**
- Tap any trip → full detail view
- Swipe left to delete
- Each profile has completely separate history

---

## Feature 14 — Plan Reminder Notifications

**What it does:**
Automatic reminders so you never forget a planned trip.

- **Evening before** (7:00 PM): "Tomorrow: [Plan Name] — Your plan starts tomorrow"
- **Morning of** (8:00 AM): "Today: [Plan Name] — Your plan starts today 🗺️"

Notifications are created automatically when you save a plan and cancelled when you delete it. The toggle in Settings → Notifications lets you turn them on/off. If iOS permission is denied, a button links directly to iPhone Settings.

---

## Feature 15 — Settings

**What it does:**
Personalise the app. All settings are instant — no save button needed.

- **Profile** — tap to manage profiles (rename, delete, add new)
- **Trip Defaults** — default travel mode pre-selected in every new plan
- **Notifications** — toggle reminders on/off
- **Appearance** — System (follows iPhone) / Light / Dark — applies instantly everywhere
- **About** — app version
- **Reset Onboarding** — shows welcome screens again on next launch

---

## Technical Summary

| Area | Technology |
|---|---|
| UI framework | SwiftUI (iOS 17+) |
| Architecture | MVVM |
| Maps | MapKit |
| Routing | MKDirections (free, Apple) |
| Place search | MKLocalSearch (free, Apple) |
| GPS | CoreLocation + CLLocationManager |
| Route algorithm | Nearest-neighbour + binary min-heap (O(n log n)) |
| Notifications | UserNotifications framework |
| Data storage | JSON files + UserDefaults |
| Async | Swift async/await (no Combine) |
| Cost | Free — no paid third-party APIs |

---

*Built with SwiftUI + MapKit — iOS 17+*
