import AppKit
import SwiftUI

struct AudioFlipMenuView: View {
    @ObservedObject var store: AudioDeviceStore

    var body: some View {
        Menu("Output") {
            deviceItems(store.outputs, kind: .output)
        }

        Menu("Input") {
            deviceItems(store.inputs, kind: .input)
        }

        if let errorMessage = store.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Audio device error: \(errorMessage)")
        }

        Divider()
        Button("Quit AudioFlip") {
            NSApplication.shared.terminate(nil)
        }
    }

    @ViewBuilder
    private func deviceItems(_ devices: [AudioDevice], kind: AudioDeviceKind) -> some View {
        if devices.isEmpty {
            Text("No \(kind.displayName.lowercased()) devices available")
                .foregroundStyle(.secondary)
        } else {
            ForEach(devices) { device in
                Button {
                    store.select(device.id, for: kind)
                } label: {
                    HStack {
                        if store.isSelected(device.id, for: kind) {
                            Image(systemName: "checkmark")
                        }
                        Text(device.name)
                    }
                }
                .accessibilityLabel(device.name)
                .accessibilityAddTraits(store.isSelected(device.id, for: kind) ? .isSelected : [])
            }
        }
    }
}
