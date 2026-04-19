import Foundation

struct PlannedSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    var weekNumber: Int
    var dayOfWeek: Int
    var scheduledDate: Date
    var workoutType: WorkoutType
    var targetDistanceKm: Double?
    var targetPaceDescription: String?
    var notes: String?
    var sortOrder: Int

    var targetDistanceMi: Double? {
        targetDistanceKm.map { DistanceFormatter.miles(from: $0) }
    }

    /// Full coaching text for display: session `notes` plus `targetPaceDescription` when that line is not already contained in the notes (templates often split them across JSON fields).
    var verbatimCoachNotesForDisplay: String {
        let paceTrimmed = targetPaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bodyTrimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pace = paceTrimmed.isEmpty ? nil : paceTrimmed
        let body = bodyTrimmed.isEmpty ? nil : bodyTrimmed
        switch (pace, body) {
        case (nil, nil):
            return ""
        case let (p?, nil):
            return p
        case let (nil, b?):
            return b
        case let (p?, b?):
            if b.lowercased().contains(p.lowercased()) {
                return b
            }
            return "\(p)\n\n\(b)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case scheduledDate = "scheduled_date"
        case workoutType = "workout_type"
        case targetDistanceKm = "target_distance_km"
        case targetPaceDescription = "target_pace_description"
        case notes
        case sortOrder = "sort_order"
    }

    /// Best-effort display range parsed from verbatim coach text (notes + pace description).
    /// Runs prefer a parsed "N-M mi" range and fall back to a single-value mi formatted from
    /// `targetDistanceMi`. Cross-training / other non-distance sessions try "N-M hr" then
    /// "N-M min". Rest days return nil.
    var displayTargetRange: String? {
        if workoutType == .rest { return nil }

        let text = [targetPaceDescription, notes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if targetDistanceMi != nil {
            if let range = Self.firstRange(in: text, unitPattern: "mi(?:les?)?") {
                return "\(range) mi"
            }
            if let mi = targetDistanceMi {
                return "\(Self.formatSingle(mi)) mi"
            }
        }

        if let range = Self.firstRange(in: text, unitPattern: "hrs?|hours?") {
            return "\(range) hr"
        }
        if let range = Self.firstRange(in: text, unitPattern: "mins?|minutes?") {
            return "\(range) min"
        }
        return nil
    }

    /// Finds the first "N-M <unit>" occurrence in `text` where N and M are numeric and the
    /// dash is `-`, en-dash, or em-dash. Returns the range as an en-dashed string (e.g. "8–14")
    /// or nil if none is found. The unit keyword must follow the second number (with optional
    /// whitespace) to avoid matching pace notations like "4:30–4:45/km".
    private static func firstRange(in text: String, unitPattern: String) -> String? {
        let pattern = #"(\d+(?:\.\d+)?)\s*[\-\u2013\u2014]\s*(\d+(?:\.\d+)?)\s*(?:"# + unitPattern + #")\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 3 else {
            return nil
        }
        let low = ns.substring(with: match.range(at: 1))
        let high = ns.substring(with: match.range(at: 2))
        return "\(low)\u{2013}\(high)"
    }

    private static func formatSingle(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
