import AppKit
import SwiftUI

struct AudioFlipMenuView: View {
    @ObservedObject var store: AudioDeviceStore

    var body: some View {
        VStack(spacing: 0) {
            if needsScrolling {
                ScrollView {
                    deviceSections
                }
                .frame(height: listViewportHeight)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            } else {
                deviceSections
            }

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

    private var deviceSections: some View {
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

    private var listContentHeight: CGFloat {
        let sectionHeaderAndSpacing: CGFloat = 26
        let deviceRows = rowHeight(for: store.outputs.count) + rowHeight(for: store.inputs.count)
        let volumeRows = CGFloat((store.outputs.isEmpty ? 0 : 1) + (store.inputs.isEmpty ? 0 : 1)) * 32
        let errorHeight: CGFloat = store.errorMessage == nil ? 0 : 44

        return 24 + (sectionHeaderAndSpacing * 2) + volumeRows + deviceRows + 25 + errorHeight
    }

    private var needsScrolling: Bool {
        listContentHeight > 560
    }

    private var listViewportHeight: CGFloat {
        min(listContentHeight, 560)
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

                Text(devices.first(where: { store.isSelected($0.id, for: kind) })?.name ?? "No device")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 132, alignment: .trailing)
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
                volumeControl(for: kind)

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

    @ViewBuilder
    private func volumeControl(for kind: AudioDeviceKind) -> some View {
        let volume = store.volume(for: kind)

        HStack(spacing: 8) {
            Image(systemName: symbol(for: kind))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            if let volume {
                Slider(
                    value: Binding(
                        get: { store.volume(for: kind)?.value ?? volume.value },
                        set: { store.setVolume($0, for: kind) }
                    ),
                    in: 0...1
                )
                .controlSize(.small)
                .disabled(!volume.isSettable)
                .accessibilityLabel("\(kind.displayName) volume")
                .accessibilityValue("\(Int((volume.value * 100).rounded())) percent")

                Text("\(Int((volume.value * 100).rounded()))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            } else {
                Text("Volume control unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
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
