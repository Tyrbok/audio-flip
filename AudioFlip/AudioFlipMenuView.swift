import AppKit
import SwiftUI

struct AudioFlipMenuView: View {
    @ObservedObject var store: AudioDeviceStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    deviceSection(store.outputs, kind: .output)

                    sectionDivider

                    deviceSection(store.inputs, kind: .input)

                    if let errorMessage = store.errorMessage {
                        errorRow(errorMessage)
                    }
                }
                .padding(12)
            }
            .frame(height: listViewportHeight)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit AudioFlip", systemImage: "power")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .frame(height: 40)
        }
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
    }

    private var listViewportHeight: CGFloat {
        let sectionHeaderAndSpacing: CGFloat = 26
        let deviceRows = rowHeight(for: store.outputs.count) + rowHeight(for: store.inputs.count)
        let errorHeight: CGFloat = store.errorMessage == nil ? 0 : 44

        return min(24 + (sectionHeaderAndSpacing * 2) + deviceRows + 25 + errorHeight, 560)
    }

    private func rowHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 34 }
        return CGFloat(count * 36 + (count - 1) * 3)
    }

    private func deviceSection(_ devices: [AudioDevice], kind: AudioDeviceKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol(for: kind))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(kind.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)

            if devices.isEmpty {
                Text("No \(kind.displayName.lowercased()) devices available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 34)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            } else {
                VStack(spacing: 3) {
                    ForEach(devices) { device in
                        let isSelected = store.isSelected(device.id, for: kind)
                        AudioDeviceRow(device: device, isSelected: isSelected) {
                            store.select(device.id, for: kind)
                        }
                    }
                }
            }
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .accessibilityLabel("Audio device error: \(message)")
    }

    private func symbol(for kind: AudioDeviceKind) -> String {
        switch kind {
        case .output: "speaker.wave.2.fill"
        case .input: "mic.fill"
        }
    }
}

private struct AudioDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(device.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(rowBackground)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(device.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovered ? 0.18 : 0.12)
        }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }
}
