import SwiftUI

enum SessionComponents {

    // MARK: - Oura Recovery Row

    static func recoveryRow(_ recovery: OuraDaily) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if let score = recovery.readinessScore {
                    HStack(spacing: 3) {
                        Image(systemName: score >= 85 ? "crown.fill" : "circle.fill")
                            .foregroundStyle(readinessColor(recovery.readinessLevel))
                        Text("Rdy").font(TrailFont.data).foregroundStyle(.secondary)
                        Text("\(score)").font(TrailFont.data)
                    }
                }
                if let sleep = recovery.sleepScore {
                    HStack(spacing: 3) {
                        Image(systemName: "moon.fill").foregroundStyle(.blue)
                        Text("Slp").font(TrailFont.data).foregroundStyle(.secondary)
                        Text("\(sleep)").font(TrailFont.data)
                    }
                }
                if let hrv = recovery.hrvAverage {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform.path.ecg").foregroundStyle(.purple)
                        Text("HRV").font(TrailFont.data).foregroundStyle(.secondary)
                        Text(String(format: "%.0f", hrv)).font(TrailFont.data)
                    }
                }
                if let rhr = recovery.restingHr {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                        Text("RHR").font(TrailFont.data).foregroundStyle(.secondary)
                        Text("\(rhr)").font(TrailFont.data)
                    }
                }
                Spacer()
            }

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
                        .font(TrailFont.data)
                    Spacer()
                    if !activity.isRun {
                        Text(activity.activityTypeDisplay)
                            .font(TrailFont.meta)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                    Image(systemName: "arrow.up.right.square")
                        .font(TrailFont.meta)
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
                            .font(TrailFont.data)
                            .foregroundStyle(.red)
                    }

                    if let elev = activity.elevationGainM, activity.isRun {
                        Label(String(format: "%.0f ft", elev * 3.281), systemImage: "mountain.2.fill")
                            .font(TrailFont.data)
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
