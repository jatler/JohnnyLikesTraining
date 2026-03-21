import Foundation

struct ProgressionSuggestion: Identifiable {
    let id = UUID()
    let exerciseName: String
    let currentSets: Int
    let currentReps: Int
    let currentWeightKg: Double?
    let suggestedSets: Int
    let suggestedReps: Int
    let suggestedWeightKg: Double?
    let reason: String
}

enum ProgressionEngine {

    struct Config {
        var repRangeBottom: Int = 8
        var repRangeTop: Int = 12
        var weightIncrementKg: Double = 2.5
        var deloadFrequency: Int = 4
        var deloadVolumeReduction: Double = 0.4
        var weeksToAnalyze: Int = 2
        var highMileageThresholdKm: Double = 80
    }

    static let defaultConfig = Config()

    // MARK: - Deload Detection

    static func isDeloadWeek(_ weekNumber: Int, config: Config = defaultConfig) -> Bool {
        weekNumber > 0 && weekNumber % config.deloadFrequency == 0
    }

    // MARK: - Compute Suggestions

    static func suggest(
        for exercise: StrengthTemplateExercise,
        logs: [StrengthLog],
        weeklyRunDistanceKm: Double,
        recentReadiness: [OuraDaily],
        currentWeek: Int,
        config: Config = defaultConfig
    ) -> ProgressionSuggestion? {

        if isDeloadWeek(currentWeek, config: config) {
            let deloadSets = max(1, Int(Double(exercise.targetSets) * (1.0 - config.deloadVolumeReduction)))
            return ProgressionSuggestion(
                exerciseName: exercise.exerciseName,
                currentSets: exercise.targetSets,
                currentReps: exercise.targetReps,
                currentWeightKg: exercise.targetWeightKg,
                suggestedSets: deloadSets,
                suggestedReps: exercise.targetReps,
                suggestedWeightKg: exercise.targetWeightKg,
                reason: "Deload week — reducing volume"
            )
        }

        let avgReadiness = averageReadiness(recentReadiness)
        if let avg = avgReadiness, avg < 60 {
            return ProgressionSuggestion(
                exerciseName: exercise.exerciseName,
                currentSets: exercise.targetSets,
                currentReps: exercise.targetReps,
                currentWeightKg: exercise.targetWeightKg,
                suggestedSets: exercise.targetSets,
                suggestedReps: exercise.targetReps,
                suggestedWeightKg: exercise.targetWeightKg,
                reason: "Recovery low (avg readiness \(Int(avg))) — maintain current load"
            )
        }

        if weeklyRunDistanceKm > config.highMileageThresholdKm {
            let reducedSets = max(1, exercise.targetSets - 1)
            return ProgressionSuggestion(
                exerciseName: exercise.exerciseName,
                currentSets: exercise.targetSets,
                currentReps: exercise.targetReps,
                currentWeightKg: exercise.targetWeightKg,
                suggestedSets: reducedSets,
                suggestedReps: exercise.targetReps,
                suggestedWeightKg: exercise.targetWeightKg,
                reason: "High running volume (\(Int(weeklyRunDistanceKm)) km) — reducing sets"
            )
        }

        guard !logs.isEmpty else { return nil }

        let hitAllReps = logs.allSatisfy { $0.actualReps >= exercise.targetReps }
        guard hitAllReps else { return nil }

        if exercise.targetReps < config.repRangeTop {
            return ProgressionSuggestion(
                exerciseName: exercise.exerciseName,
                currentSets: exercise.targetSets,
                currentReps: exercise.targetReps,
                currentWeightKg: exercise.targetWeightKg,
                suggestedSets: exercise.targetSets,
                suggestedReps: exercise.targetReps + 2,
                suggestedWeightKg: exercise.targetWeightKg,
                reason: "Hit all reps — increase reps"
            )
        }

        if !exercise.isBodyweight, let weight = exercise.targetWeightKg {
            return ProgressionSuggestion(
                exerciseName: exercise.exerciseName,
                currentSets: exercise.targetSets,
                currentReps: exercise.targetReps,
                currentWeightKg: weight,
                suggestedSets: exercise.targetSets,
                suggestedReps: config.repRangeBottom,
                suggestedWeightKg: weight + config.weightIncrementKg,
                reason: "Top of rep range — increase weight, reset reps"
            )
        }

        return nil
    }

    // MARK: - Apply Deload to Sessions

    static func applyDeload(
        sets: Int,
        reps: Int,
        weightKg: Double?,
        config: Config = defaultConfig
    ) -> (sets: Int, reps: Int, weightKg: Double?) {
        let deloadSets = max(1, Int(Double(sets) * (1.0 - config.deloadVolumeReduction)))
        return (deloadSets, reps, weightKg)
    }

    // MARK: - Running Load for a Week

    static func weeklyRunDistance(
        sessions: [PlannedSession],
        weekNumber: Int
    ) -> Double {
        sessions
            .filter { $0.weekNumber == weekNumber && $0.workoutType != .strength }
            .compactMap(\.targetDistanceKm)
            .reduce(0, +)
    }

    // MARK: - Helpers

    private static func averageReadiness(_ data: [OuraDaily]) -> Double? {
        let scores = data.compactMap(\.readinessScore)
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
}
