import AppKit
import SwiftUI

struct AudioFlipMenuView: View {
    @ObservedObject var store: AudioDeviceStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    private let maxDevicesWithoutScrolling = 10

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

            launchAtLoginControls

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
        .onAppear {
            launchAtLogin.refreshStatus()
        }
    }

    private var launchAtLoginControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )) {
                Label("Launch at login", systemImage: "power")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(launchAtLogin.isUnavailable)

            if launchAtLogin.requiresApproval {
                Text("Allow AudioFlip in Login Items in System Settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Open Login Items Settings") {
                    launchAtLogin.openLoginItemsSettings()
                }
                .font(.system(size: 11))
                .buttonStyle(.link)
            } else if launchAtLogin.isUnavailable {
                Text("macOS couldn't find AudioFlip as a login item.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = launchAtLogin.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var deviceListDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
    }

    private var deviceSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            deviceSection(store.outputs, kind: .output)
            deviceSection(store.inputs, kind: .input)

            if let errorMessage = store.errorMessage {
                errorRow(errorMessage)
            }
        }
        .padding(12)
    }

    private var listContentHeight: CGFloat {
        let errorHeight: CGFloat = store.errorMessage == nil ? 0 : 44

        return 24
            + sectionHeight(for: store.outputs)
            + sectionHeight(for: store.inputs)
            + 10
            + errorHeight
    }

    private var needsScrolling: Bool {
        store.outputs.count + store.inputs.count > maxDevicesWithoutScrolling
    }

    private var listViewportHeight: CGFloat {
        min(listContentHeight, 560)
    }

    private func rowHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 34 }
        return CGFloat(count * 36 + (count - 1) * 3)
    }

    private func sectionHeight(for devices: [AudioDevice]) -> CGFloat {
        let headerHeight: CGFloat = 26
        let cardVerticalPadding: CGFloat = 24

        guard !devices.isEmpty else {
            return headerHeight + 34 + cardVerticalPadding
        }

        let volumeHeight: CGFloat = 24
        let dividerHeight: CGFloat = 17
        return headerHeight + volumeHeight + dividerHeight + rowHeight(for: devices.count) + cardVerticalPadding
    }

    private func deviceSection(_ devices: [AudioDevice], kind: AudioDeviceKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(kind.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            if devices.isEmpty {
                Text("No \(kind.displayName.lowercased()) devices available")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 34)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            } else {
                volumeControl(for: kind)
                deviceListDivider

                VStack(spacing: 3) {
                    ForEach(devices) { device in
                        let isSelected = store.isSelected(device.id, for: kind)
                        AudioDeviceRow(device: device, kind: kind, isSelected: isSelected) {
                            store.select(device.id, for: kind)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.primary.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
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
    let kind: AudioDeviceKind
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)

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

    private var symbolName: String {
        let normalizedName = device.name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let matches: ([String]) -> Bool = { terms in
            terms.contains { normalizedName.contains($0) }
        }

        if matches(["display", "displayport", "hdmi", "monitor", "ultrafine", "pantalla"]) {
            return "display"
        }
        if matches(["headphone", "headset", "airpods", "earbuds", "earphones", "cascos", "auricular", "audifono"]) {
            return "headphones"
        }
        if matches(["macbook", "built-in", "built in", "integrado", "portatil"]) {
            return "laptopcomputer"
        }
        if matches(["speaker", "soundbar", "homepod", "altavoz", "parlante"]) {
            return "speaker.wave.2.fill"
        }

        return kind == .input ? "mic.fill" : "speaker.wave.2.fill"
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(isHovered ? 0.18 : 0.12)
        }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }
}
