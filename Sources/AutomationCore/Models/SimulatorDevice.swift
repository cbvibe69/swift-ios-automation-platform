import Foundation

/// Representation of a simulator device.
public struct SimulatorDevice: Sendable {
    public let id: String
    public let name: String
    public let runtime: String
    public let deviceType: String

    public init(id: String, name: String, runtime: String, deviceType: String) {
        self.id = id
        self.name = name
        self.runtime = runtime
        self.deviceType = deviceType
    }
}
