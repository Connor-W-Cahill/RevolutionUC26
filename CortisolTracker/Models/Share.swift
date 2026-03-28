import Foundation

struct Share: Identifiable, Codable {
    var id: String            // ownerID_viewerID
    var ownerID: String
    var viewerID: String
    var status: ShareStatus
    var permissions: SharePermissions
    var createdAt: Date
    var updatedAt: Date

    var isActive: Bool { status == .active }

    enum ShareStatus: String, Codable {
        case active = "active"
        case revoked = "revoked"
    }

    struct SharePermissions: Codable {
        var latestStress: Bool
        var history: Bool
        var groupStats: Bool

        init(latestStress: Bool = true, history: Bool = false, groupStats: Bool = false) {
            self.latestStress = latestStress
            self.history = history
            self.groupStats = groupStats
        }
    }

    init(
        ownerID: String,
        viewerID: String,
        permissions: SharePermissions = SharePermissions(),
        status: ShareStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = "\(ownerID)_\(viewerID)"
        self.ownerID = ownerID
        self.viewerID = viewerID
        self.status = status
        self.permissions = permissions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
