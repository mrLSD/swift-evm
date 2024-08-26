import Foundation

/// EVM Handler protocol
protocol Handler {}

///
typealias Operation = (_ state: Machine, _ handler: Handler) -> ()
