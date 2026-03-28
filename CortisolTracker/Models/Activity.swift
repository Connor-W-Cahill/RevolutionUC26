import Foundation

struct Activity: Identifiable, Codable {
    var id: String
    var userID: String
    var date: Date
    var category: ActivityCategory
    var title: String
    var notes: String?
    var rating: Int?  // 1-5 subjective rating

    init(id: String = UUID().uuidString, userID: String, date: Date = Date(),
         category: ActivityCategory, title: String, notes: String? = nil, rating: Int? = nil) {
        self.id = id
        self.userID = userID
        self.date = date
        self.category = category
        self.title = title
        self.notes = notes
        self.rating = rating
    }
}

enum ActivityCategory: String, Codable, CaseIterable {
    case sleep = "Sleep"
    case diet = "Diet"
    case exercise = "Exercise"
    case work = "Work"
    case social = "Social"
    case meditation = "Meditation"
    case other = "Other"

    var icon: String {
        switch self {
        case .sleep: return "bed.double"
        case .diet: return "fork.knife"
        case .exercise: return "figure.run"
        case .work: return "laptopcomputer"
        case .social: return "person.2"
        case .meditation: return "brain.head.profile"
        case .other: return "ellipsis.circle"
        }
    }
}
