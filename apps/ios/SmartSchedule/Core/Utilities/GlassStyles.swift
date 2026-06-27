import SwiftUI

struct GlassPanel: ViewModifier {
    var tint: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { Glass.regular.tint($0.opacity(0.16)) } ?? .regular,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        } else {
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(0.18))
                }
        }
    }
}

extension View {
    func betaGlassPanel(tint: Color? = nil) -> some View {
        modifier(GlassPanel(tint: tint))
    }
}

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
    }
}

struct ConfidenceGauge: View {
    var value: Double

    var body: some View {
        HStack(spacing: 6) {
            Gauge(value: max(0, min(value, 1))) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(tint)
            .frame(width: 64)

            Text(value, format: .percent.precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityLabel("置信度 \(Int(value * 100))%")
    }

    private var tint: Color {
        switch value {
        case 0.8...: .green
        case 0.55...: .orange
        default: .red
        }
    }
}

extension Date {
    var betaShortDateTime: String {
        formatted(date: .abbreviated, time: .shortened)
    }

    var betaTimeOnly: String {
        formatted(date: .omitted, time: .shortened)
    }
}
