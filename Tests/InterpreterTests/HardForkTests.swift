import Nimble
import PrimitiveTypes
import Quick

@testable import Interpreter

final class InterpreterHardForkSpec: QuickSpec {
    override class func spec() {
        describe("Hard fork Enumeration") {
            context("HardFork rawValue") {
                it("should have correct rawValue for all HardFork cases") {
                    let hardForkRawValues: [HardFork: UInt8] = [
                        .Istanbul: 0x00,
                        .Berlin: 0x01,
                        .London: 0x02,
                        .Paris: 0x03,
                        .Shanghai: 0x04,
                        .Cancun: 0x05,
                        .Prague: 0x06,
                        .Osaka: 0x07,
                    ]

                    // Check that covared all cases
                    expect(HardFork.allCases.count).to(equal(hardForkRawValues.count))

                    for (hardFork, rawValue) in hardForkRawValues {
                        expect(hardFork.rawValue).to(
                            equal(rawValue),
                            description:
                            "HardFork \(hardFork) should have rawValue \(String(format: "0x%02X", rawValue))")
                    }
                }

                it(" latest hard work should be correct") {
                    expect(HardFork.latest()).to(equal(HardFork.Prague))
                }
            }

            context("HardFork in Machine") {
                it("validate Machine hard fork") {
                    let m = Machine(data: [], code: [], gasLimit: 100, memoryLimit: 1024, handler: TestHandler(), hardFork: HardFork.London)
                    expect(m.hardFork).to(equal(HardFork.London))
                }

                it("validate Machine hard fork has latest hard fork") {
                    let m = Machine(data: [], code: [], gasLimit: 100, handler: TestHandler())
                    expect(m.hardFork).to(equal(HardFork.latest()))
                }
            }
        }

        context("Test for description of each case") {
            it("should return correct description for all Opcode cases") {
                let hardForkDescriptions: [HardFork: String] = [
                    .Istanbul: "Istanbul",
                    .Berlin: "Berlin",
                    .London: "London",
                    .Paris: "Paris",
                    .Shanghai: "Shanghai",
                    .Cancun: "Cancun",
                    .Prague: "Prague",
                    .Osaka: "Osaka",
                ]

                // Check that covared all cases
                expect(HardFork.allCases.count).to(equal(hardForkDescriptions.count))

                for (hardFork, description) in hardForkDescriptions {
                    expect(hardFork.description).to(
                        equal(description),
                        description:
                        "\(hardFork) should have description \"\(description)\"")
                }
            }
        }

        context("Validate functions isHardFork") {
            it("should return true for all cases") {
                expect(HardFork.Istanbul.isIstanbul()).to(beTrue())
                expect(HardFork.Berlin.isBerlin()).to(beTrue())
                expect(HardFork.London.isLondon()).to(beTrue())
                expect(HardFork.Paris.isParis()).to(beTrue())
                expect(HardFork.Shanghai.isShanghai()).to(beTrue())
                expect(HardFork.Cancun.isCancun()).to(beTrue())
                expect(HardFork.Prague.isPrague()).to(beTrue())
                expect(HardFork.Osaka.isOsaka()).to(beTrue())
            }
        }
    }
}
