import SwiftUI

enum SessionComponents {

    // MARK: - Oura Recovery Row

    static func recoveryRow(_ recovery: OuraDaily) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let score = recovery.readinessScore {
                    HStack(spacing: 4) {
                        if score >= 85 {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        } else {
                            Circle()
                                .fill(readinessColor(recovery.readinessLevel))
                                .frame(width: 8, height: 8)
                        }
                        Text("Readiness \(score)")
                            .font(.caption)
                    }
                }
                if let sleep = recovery.sleepScore {
                    HStack(spacing: 4) {
                        if sleep >= 85 {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        } else {
                            Image(systemName: "moon.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        Text("Sleep \(sleep)")
                            .font(.caption)
                    }
                }
                if let hrv = recovery.hrvAverage {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text(String(format: "HRV %.0f", hrv))
                            .font(.caption)
                    }
                }
                if let rhr = recovery.restingHr {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("RHR \(rhr)")
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Image("OuraLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 12)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Completed: \(activity.name)")
                        .font(.subheadline.bold())
                    Spacer()
                    if !activity.isRun {
                        Text(activity.activityTypeDisplay)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let elev = activity.elevationGainM, activity.isRun {
                        Label(String(format: "%.0f ft", elev * 3.281), systemImage: "mountain.2.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                HStack {
                    Spacer()
                    Image("PoweredByStrava")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 12)
                }
            }
            .padding()
            .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Comparison Cell

    static func comparisonCell(title: String, actual: String, planned: String?, delta: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(actual)
                .font(.subheadline.bold())

            if let planned {
                Text("Plan: \(planned)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let delta, abs(delta) >= 1 {
                Text(String(format: "%+.0f%%", delta))
                    .font(.caption.bold())
                    .foregroundStyle(delta >= 0 ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
}
