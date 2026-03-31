import SwiftUI

struct UnmatchedActivitiesView: View {
    @Environment(StravaService.self) private var strava

    var body: some View {
        let unmatched = strava.activities
            .filter { $0.matchedSessionId == nil }
            .sorted { $0.activityDate > $1.activityDate }

        VStack(alignment: .leading, spacing: 12) {
            Text("Extra Activities")
                .font(.headline)

            if unmatched.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.swapAccent)
                    Text("All activities matched to planned sessions!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ForEach(unmatched) { activity in
                    activityRow(activity)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Row

    private func activityRow(_ activity: StravaActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForActivityType(activity.activityType))
                .font(.title3)
                .foregroundStyle(Color.swapAccent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(activity.activityTypeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(activity.activityDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", activity.distanceMi))
                    .font(.subheadline.bold())

                Text(activity.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Icon Mapping

    private func iconForActivityType(_ type: String) -> String {
        switch type {
        case "Run", "TrailRun", "VirtualRun":
            return "figure.run"
        case "Ride", "MountainBikeRide", "GravelRide", "EBikeRide", "VirtualRide":
            return "figure.outdoor.cycle"
        case "Swim":
            return "figure.pool.swim"
        case "Hike":
            return "figure.hiking"
        case "WeightTraining", "Crossfit":
            return "dumbbell.fill"
        case "Yoga":
            return "figure.yoga"
        case "Walk":
            return "figure.walk"
        case "Rowing":
            return "figure.rower"
        case "Elliptical":
            return "figure.elliptical"
        case "CrossCountrySkiing", "BackcountrySki", "NordicSki":
            return "figure.skiing.crosscountry"
        case "AlpineSki":
            return "figure.skiing.downhill"
        case "Snowboard":
            return "figure.snowboarding"
        case "RockClimbing":
            return "figure.climbing"
        case "StairStepper":
            return "figure.stairs"
        default:
            return "figure.mixed.cardio"
        }
    }
}
