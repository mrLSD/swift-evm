@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class LogSpec: QuickSpec {
    override class func spec() {
        describe("Log struct") {
            // Тестовые данные (объявлены внутри, чтобы избежать проблем с изоляцией в Swift 6)
            let addr1 = H160(from: [UInt8](repeating: 0x11, count: 20))
            let addr2 = H160(from: [UInt8](repeating: 0x22, count: 20))

            let topic1 = H256(from: [UInt8](repeating: 0xaa, count: 32))
            let topic2 = H256(from: [UInt8](repeating: 0xbb, count: 32))

            let data1: [UInt8] = [0x01, 0x02, 0x03]
            let data2: [UInt8] = [0xff, 0xee]

            context("initialization") {
                it("should correctly store provided values") {
                    let log = Log(address: addr1, topics: [topic1, topic2], data: data1)

                    expect(log.address).to(equal(addr1))
                    expect(log.topics).to(equal([topic1, topic2]))
                    expect(log.data).to(equal(data1))
                }

                it("should handle empty topics and data") {
                    let log = Log(address: addr1, topics: [], data: [])

                    expect(log.topics).to(beEmpty())
                    expect(log.data).to(beEmpty())
                }
            }

            context("equality (Equatable)") {
                it("should be equal if all properties match") {
                    let log1 = Log(address: addr1, topics: [topic1], data: data1)
                    let log2 = Log(address: addr1, topics: [topic1], data: data1)

                    expect(log1).to(equal(log2))
                }

                it("should not be equal if addresses differ") {
                    let log1 = Log(address: addr1, topics: [topic1], data: data1)
                    let log2 = Log(address: addr2, topics: [topic1], data: data1)

                    expect(log1).toNot(equal(log2))
                }

                it("should not be equal if topics differ") {
                    let log1 = Log(address: addr1, topics: [topic1], data: data1)
                    let log2 = Log(address: addr1, topics: [topic2], data: data1)

                    expect(log1).toNot(equal(log2))
                }

                it("should not be equal if topics order differs") {
                    let log1 = Log(address: addr1, topics: [topic1, topic2], data: data1)
                    let log2 = Log(address: addr1, topics: [topic2, topic1], data: data1)

                    expect(log1).toNot(equal(log2))
                }

                it("should not be equal if data differs") {
                    let log1 = Log(address: addr1, topics: [topic1], data: data1)
                    let log2 = Log(address: addr1, topics: [topic1], data: data2)

                    expect(log1).toNot(equal(log2))
                }
            }

            context("data integrity") {
                it("should preserve the exact byte sequence in data") {
                    let complexData: [UInt8] = (0 ..< 100).map { UInt8($0) }
                    let log = Log(address: addr1, topics: [], data: complexData)

                    expect(log.data.count).to(equal(100))
                    expect(log.data[50]).to(equal(50))
                    expect(log.data).to(equal(complexData))
                }
            }
        }
    }
}
