import Foundation

public protocol StreamEndpointProviding: Sendable {
    var liveStreamURL: URL { get }
}

public struct DirectKXSFEndpoint: StreamEndpointProviding {
    public init() {}

    public let liveStreamURL = URL(string: "http://stream.kxsf.fm:8000/sfcr")!
}
