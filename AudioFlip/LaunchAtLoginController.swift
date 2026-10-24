import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
        status = service.status
    }

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    var isUnavailable: Bool {
        status == .notFound
    }

    func refreshStatus() {
        status = service.status
        errorMessage = nil
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }

        errorMessage = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            status = service.status
        } catch {
            status = service.status
            errorMessage = error.localizedDescription
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
