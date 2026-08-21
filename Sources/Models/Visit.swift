import Foundation

/// One check-in event at a `Place`. A place can be visited many times; each
/// visit is its own record so a place's history reads as a timeline.
struct Visit: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var note: String = ""

    init(date: Date = Date(), note: String = "") {
        self.date = date
        self.note = note
    }
}
