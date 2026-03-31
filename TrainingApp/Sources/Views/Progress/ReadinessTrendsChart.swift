import Charts
import SwiftUI

struct ReadinessTrendsChart: View {
    @Environment(OuraService.self) private var oura

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Trends (30 Days)")
                .font(.headline)

            let days = oura.recentReadiness(days: 30)

            if days.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Connect Oura Ring to see recovery trends.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(days) { day in
                        if let readiness = day.readinessScore {
                            LineMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Score", readiness),
                                series: .value("Metric", "Readiness")
                            )
                            .foregroundStyle(Color.swapAccent)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Score", readiness)
                            )
                            .foregroundStyle(Color.swapAccent)
                            .symbolSize(20)
                        }

                        if let sleep = day.sleepScore {
                            LineMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Score", sleep),
                                series: .value("Metric", "Sleep")
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Score", sleep)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(20)
                        }

                        if let hrv = day.hrvAverage {
                            // Scale HRV to 0-100 range for display alongside scores
                            let scaledHRV = min(hrv, 100)
                            LineMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Score", scaledHRV),
                                series: .value("Metric", "HRV")
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Date", day.date, unit: .day),
                                y: .value("Score", scaledHRV)
                            )
                            .foregroundStyle(.orange)
                            .symbolSize(20)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxisLabel("Score")
                .chartLegend(position: .bottom)
                .frame(height: 220)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
