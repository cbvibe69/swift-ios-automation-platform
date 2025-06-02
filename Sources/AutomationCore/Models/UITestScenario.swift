import Foundation

/// Representation of a UI test scenario.
public struct UITestScenario: Sendable {
    public let name: String
    public let steps: [UITestStep]
    public let expectedOutcome: UITestOutcome

    public init(name: String, steps: [UITestStep], expectedOutcome: UITestOutcome) {
        self.name = name
        self.steps = steps
        self.expectedOutcome = expectedOutcome
    }
}

/// Placeholder representing a single UI test step.
public struct UITestStep: Sendable {
    public let description: String

    public init(description: String) {
        self.description = description
    }
}

/// Placeholder representing the outcome of a UI test scenario.
public enum UITestOutcome: Sendable {
    case success
    case failure(String)
}
