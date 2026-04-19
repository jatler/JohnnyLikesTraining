import SwiftUI

enum SessionComponents {

    // MARK: - Oura Recovery Row

    static func recoveryRow(_ recovery: OuraDaily) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECOVERY")
                    .font(TrailFont.data).tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Image("OuraLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 12)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                if let score = recovery.readinessScore {
                    recoveryStat(
                        label: "Rdy",
                        value: "\(score)",
                        icon: score >= 85 ? "crown.fill" : "circle.fill",
                        color: readinessColor(recovery.readinessLevel)
                    )
                }
                if let sleep = recovery.sleepScore {
                    recoveryStat(label: "Slp", value: "\(sleep)", icon: "moon.fill", color: .blue)
                }
                if let hrv = recovery.hrvAverage {
                    recoveryStat(label: "HRV", value: String(format: "%.0f", hrv), icon: "waveform.path.ecg", color: .purple)
                }
                if let rhr = recovery.restingHr {
                    recoveryStat(label: "RHR", value: "\(rhr)", icon: "heart.fill", color: .red)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }

    private static func recoveryStat(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 13))
            Text(value).font(TrailFont.data).fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Readiness Color

    static func readinessColor(_ level: ReadinessLevel) -> Color {
        switch level {
        case .good: .green
        case .moderate: .orange
        case .low: .red
        case .unknown: .gray
        }
    }

    // MARK: - Strava Plan vs Actual

    static func planVsActualSection(session: PlannedSession, activity: StravaActivity) -> some View {
        Link(destination: URL(string: "https://www.strava.com/activities/\(activity.stravaId)")!) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.trailGreen)
                        .frame(width: 24, height: 24)
                        .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    Text("LOGGED ACTIVITY")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(activity.name)
                        .font(TrailFont.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    if !activity.isRun {
                        Text(activity.activityTypeDisplay.uppercased())
                            .font(TrailFont.data).tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    if activity.isRun || activity.distanceKm > 0.1 {
                        comparisonCell(
                            title: "Distance",
                            actual: String(format: "%.1f mi", activity.distanceMi),
                            planned: session.targetDistanceMi.map { String(format: "%.1f mi", $0) },
                            delta: session.targetDistanceMi.map { ((activity.distanceMi - $0) / $0) * 100 }
                        )
                    }

                    if activity.isRun {
                        comparisonCell(
                            title: "Pace",
                            actual: activity.formattedPace,
                            planned: nil,
                            delta: nil
                        )
                    }

                    comparisonCell(
                        title: "Duration",
                        actual: activity.formattedDuration,
                        planned: nil,
                        delta: nil
                    )
                }

                HStack(spacing: 16) {
                    if let hr = activity.averageHr {
                        Label("\(hr) bpm", systemImage: "heart.fill")
                            .font(TrailFont.data)
                            .foregroundStyle(.red)
                    }

                    if let elev = activity.elevationGainM, activity.isRun {
                        Label(String(format: "%.0f ft", elev * 3.281), systemImage: "mountain.2.fill")
                            .font(TrailFont.data)
                            .foregroundStyle(Color.trailGreen)
                    }

                    Spacer()

                    Image("PoweredByStrava")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 12)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comparison Cell

    static func comparisonCell(title: String, actual: String, planned: String?, delta: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(TrailFont.meta)
                .foregroundStyle(.secondary)

            Text(actual)
                .font(TrailFont.data)

            if let planned {
                Text("Plan: \(planned)")
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
            }

            if let delta, abs(delta) >= 1 {
                Text(String(format: "%+.0f%%", delta))
                    .font(TrailFont.data)
                    .foregroundStyle(delta >= 0 ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}
