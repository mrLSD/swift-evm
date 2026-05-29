import Foundation

/// Free-form `_info` block embedded in spec test JSON. Not load-bearing for execution;
/// kept only so the runner can surface labels / source / hashes in verbose mode.
///
/// Real-world fixtures vary widely in which keys are present, so every field is optional
/// and we do not enforce an unknown-fields policy.
public struct Info: Equatable, Sendable, Decodable {
    public let comment: String?
    public let fillingRpcServer: String?
    public let fillingToolVersion: String?
    public let fixtureFormat: String?
    public let generatedTestHash: String?
    public let lllcversion: String?
    public let solidity: String?
    public let source: String?
    public let sourceHash: String?
    public let labels: [String: String]?
    public let fillingTransitionTool: String?
    public let hash: String?
    public let description: String?
    public let url: String?
    public let referenceSpec: String?
    public let referenceSpecVersion: String?

    enum CodingKeys: String, CodingKey {
        case comment
        case fillingRpcServer = "filling-rpc-server"
        case fillingToolVersion = "filling-tool-version"
        case fixtureFormat = "fixture-format"
        case fixtureFormatAlt = "fixture_format"
        case generatedTestHash
        case lllcversion
        case solidity, source
        case sourceHash
        case labels
        case fillingTransitionTool = "filling-transition-tool"
        case hash, description, url
        case referenceSpec = "reference-spec"
        case referenceSpecVersion = "reference-spec-version"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.comment = try c.decodeIfPresent(String.self, forKey: .comment)
        self.fillingRpcServer = try c.decodeIfPresent(String.self, forKey: .fillingRpcServer)
        self.fillingToolVersion = try c.decodeIfPresent(String.self, forKey: .fillingToolVersion)
        let primary = try c.decodeIfPresent(String.self, forKey: .fixtureFormat)
        let alt = try c.decodeIfPresent(String.self, forKey: .fixtureFormatAlt)
        self.fixtureFormat = primary ?? alt
        self.generatedTestHash = try c.decodeIfPresent(String.self, forKey: .generatedTestHash)
        self.lllcversion = try c.decodeIfPresent(String.self, forKey: .lllcversion)
        self.solidity = try c.decodeIfPresent(String.self, forKey: .solidity)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.sourceHash = try c.decodeIfPresent(String.self, forKey: .sourceHash)
        self.labels = try c.decodeIfPresent([String: String].self, forKey: .labels)
        self.fillingTransitionTool = try c.decodeIfPresent(String.self, forKey: .fillingTransitionTool)
        self.hash = try c.decodeIfPresent(String.self, forKey: .hash)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.url = try c.decodeIfPresent(String.self, forKey: .url)
        self.referenceSpec = try c.decodeIfPresent(String.self, forKey: .referenceSpec)
        self.referenceSpecVersion = try c.decodeIfPresent(String.self, forKey: .referenceSpecVersion)
    }
}
