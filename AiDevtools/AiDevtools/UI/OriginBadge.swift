import SwiftUI

/// Compact colored badge showing where a capability originated.
struct OriginBadge: View {
    let origin: CapabilityOrigin
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: origin.systemImage)
                .font(.caption2)
            if !compact {
                Text(origin.displayLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(origin.tint)
        .padding(.horizontal, compact ? 4 : 7)
        .padding(.vertical, 2)
        .background(origin.tint.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(origin.tint.opacity(0.35), lineWidth: 0.5)
        )
        .help(origin.displayLabel)
    }
}

/// Horizontal scrollable filter pills for filtering by origin.
struct OriginFilterBar: View {
    @Binding var selected: CapabilityOrigin?
    let availableOrigins: [CapabilityOrigin]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                pill(label: "All", systemImage: "square.grid.2x2", isSelected: selected == nil, tint: .accentColor) {
                    selected = nil
                }
                ForEach(availableOrigins, id: \.self) { origin in
                    pill(
                        label: origin.displayLabel,
                        systemImage: origin.systemImage,
                        isSelected: selected == origin,
                        tint: origin.tint
                    ) {
                        selected = origin == selected ? nil : origin
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func pill(
        label: String,
        systemImage: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(label).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? tint.opacity(0.22) : Color.secondary.opacity(0.10))
            .foregroundStyle(isSelected ? tint : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension CapabilityOrigin {
    var tint: Color {
        switch self {
        case .manual: return .gray
        case .claudeHome: return .green
        case .claudeDesktop: return .indigo
        case .plugin: return .orange
        }
    }
}
