@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class AuthorizationSpec: QuickSpec {
    override class func spec() {
        describe("Authorization (EIP-7702)") {
            let authorityAddr = H160(from: [UInt8](repeating: 0x11, count: 20))
            let targetAddr = H160(from: [UInt8](repeating: 0x22, count: 20))
            let nonce: UInt64 = 42

            let validPrefix: [UInt8] = [0xef, 0x01, 0x00]

            context("initialization") {
                it("should correctly initialize with provided values") {
                    let auth = Authorization(
                        authority: authorityAddr,
                        address: targetAddr,
                        nonce: nonce,
                        isValid: true
                    )
                    expect(auth.authority).to(equal(authorityAddr))
                    expect(auth.address).to(equal(targetAddr))
                    expect(auth.nonce).to(equal(nonce))
                    expect(auth.isValid).to(beTrue())
                }

                it("should provide a valid default instance") {
                    let auth = Authorization.default
                    expect(auth.authority).to(equal(H160.ZERO))
                    expect(auth.address).to(equal(H160.ZERO))
                    expect(auth.nonce).to(equal(0))
                    expect(auth.isValid).to(beFalse())
                }
            }

            context("isDelegated") {
                it("should return true for a valid 23-byte delegation code") {
                    var code = validPrefix
                    code.append(contentsOf: targetAddr.BYTES) // + 20 bytes = 23

                    expect(Authorization.isDelegated(code: code)).to(beTrue())
                }

                it("should return false if code length is not 23 bytes") {
                    let shortCode: [UInt8] = validPrefix + [0x01, 0x02] // 5 bytes
                    let longCode: [UInt8] = validPrefix + [UInt8](repeating: 0x00, count: 21) // 24 bytes

                    expect(Authorization.isDelegated(code: shortCode)).to(beFalse())
                    expect(Authorization.isDelegated(code: longCode)).to(beFalse())
                }

                it("should return false if prefix is incorrect") {
                    var wrongPrefix: [UInt8] = [0xee, 0x01, 0x00]
                    wrongPrefix.append(contentsOf: targetAddr.BYTES)

                    expect(Authorization.isDelegated(code: wrongPrefix)).to(beFalse())
                }
            }

            context("getDelegatedAddress") {
                it("should extract the correct address from valid code") {
                    var code = validPrefix
                    code.append(contentsOf: targetAddr.BYTES)

                    let extracted = Authorization.getDelegatedAddress(code)
                    expect(extracted).to(equal(targetAddr))
                }

                it("should return nil for invalid code") {
                    let invalidCode: [UInt8] = [0x00, 0x11, 0x22]
                    expect(Authorization.getDelegatedAddress(invalidCode)).to(beNil())
                }
            }

            context("delegationCode") {
                it("should generate a correct 23-byte code") {
                    let auth = Authorization(
                        authority: authorityAddr,
                        address: targetAddr,
                        nonce: nonce,
                        isValid: true
                    )

                    let generatedCode = auth.delegationCode()

                    expect(generatedCode.count).to(equal(23))
                    expect(Array(generatedCode.prefix(3))).to(equal(validPrefix))
                    expect(Array(generatedCode.suffix(20))).to(equal(targetAddr.BYTES))
                }
            }

            context("Equatable") {
                it("should be equal for identical authorization data") {
                    let auth1 = Authorization(authority: authorityAddr, address: targetAddr, nonce: nonce, isValid: true)
                    let auth2 = Authorization(authority: authorityAddr, address: targetAddr, nonce: nonce, isValid: true)

                    expect(auth1).to(equal(auth2))
                }

                it("should not be equal if any property differs") {
                    let auth1 = Authorization(authority: authorityAddr, address: targetAddr, nonce: nonce, isValid: true)
                    let auth2 = Authorization(authority: authorityAddr, address: targetAddr, nonce: 1, isValid: true)

                    expect(auth1).toNot(equal(auth2))
                }
            }
        }
    }
}
