import Foundation

/// Groups check-ins into journeys purely from their dates.
///
/// The rule: visits less than `maxGapDays` apart belong to the same trip. That
/// is enough to separate "the week I went to Hangzhou and back" from the
/// ordinary weeks around it, without asking the user to declare anything.
///
/// A run of one lone visit is not a trip — otherwise every ordinary afternoon
/// out in your own city would appear in the list and bury the actual journeys.
enum TripBuilder {
    /// Days of quiet that end a trip. Three tolerates a rest day mid-journey
    /// while still splitting two separate weekends away.
    static let maxGapDays = 3
    /// Runs shorter than this are ordinary outings, not journeys.
    static let minVisitCount = 2

    private struct Event {
        let date: Date
        let place: Place
    }

    static func build(from places: [Place]) -> [Trip] {
        var events: [Event] = []
        for place in places {
            for visit in place.visits {
                events.append(Event(date: visit.date, place: place))
            }
        }
        guard !events.isEmpty else { return [] }
        events.sort { $0.date < $1.date }

        var clusters: [[Event]] = []
        var current: [Event] = [events[0]]
        for event in events.dropFirst() {
            let gap = Calendar.current.dateComponents(
                [.day], from: current[current.count - 1].date, to: event.date
            ).day ?? 0

            if gap <= maxGapDays {
                current.append(event)
            } else {
                clusters.append(current)
                current = [event]
            }
        }
        clusters.append(current)

        return clusters
            .filter { $0.count >= minVisitCount }
            .map(makeTrip)
            .sorted { $0.startDate > $1.startDate } // newest journey first
    }

    private static func makeTrip(from events: [Event]) -> Trip {
        var stops: [TripStop] = []
        var runPlaces: [Place] = []
        var runCity = cityName(for: events[0].place)
        var runStart = events[0].date
        var runEnd = events[0].date

        func closeRun() {
            stops.append(TripStop(
                id: stops.count + 1,
                city: runCity,
                places: runPlaces,
                startDate: runStart,
                endDate: runEnd
            ))
        }

        for event in events {
            let city = cityName(for: event.place)
            if city != runCity {
                closeRun()
                runPlaces = []
                runCity = city
                runStart = event.date
            }
            // Same place checked into twice within one leg is still one stop on
            // the map, so keep the first appearance and its position.
            if !runPlaces.contains(where: { $0.id == event.place.id }) {
                runPlaces.append(event.place)
            }
            runEnd = event.date
        }
        closeRun()

        // Stable across recomputation as long as the underlying dates don't
        // change, which is what lets a selected trip survive a redraw.
        let id = "trip-\(Int(events[0].date.timeIntervalSince1970))-\(Int(events[events.count - 1].date.timeIntervalSince1970))"
        return Trip(id: id, stops: stops)
    }

    /// Places with no city fall back to their own name, so an uncategorised
    /// check-in still appears as its own leg instead of merging into whatever
    /// came before it.
    private static func cityName(for place: Place) -> String {
        place.city.isEmpty ? place.name : place.city
    }
}
