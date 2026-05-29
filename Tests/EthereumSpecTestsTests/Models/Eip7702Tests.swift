@testable import EthereumSpecTests
import Foundation
import Nimble
import PrimitiveTypes
import Quick

final class Eip7702ConstantsSpec: QuickSpec {
    override class func spec() {
        describe("Eip7702 constants") {
            it("MAGIC byte equals 0x05") {
                expect(Eip7702.MAGIC).to(equal(0x05))
            }
            it("SECP256K1N_HALF matches the canonical value") {
                expect(Eip7702.SECP256K1N_HALF.encodeHexLower())
                    .to(equal("7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0"))
            }
        }
    }
}

final class AuthorizationItemSpec: QuickSpec {
    override class func spec() {
        describe("AuthorizationItem type") {
            let decoder = JSONDecoder()

            it("decodes all six required fields and the optional signer") {
                let json = #"""
                {
                  "chainId": "0x01",
                  "address": "0x000000000000000000000000000000000000aaaa",
                  "nonce": "0x07",
                  "r": "0x10",
                  "s": "0x20",
                  "v": "0x01",
                  "signer": "0x000000000000000000000000000000000000bbbb"
                }
                """#.data(using: .utf8)!
                let auth = try! decoder.decode(AuthorizationItem.self, from: json)
                expect(auth.chainId).to(equal(U256(from: 1)))
                expect(auth.address.BYTES.last).to(equal(0xaa))
                expect(auth.nonce).to(equal(U256(from: 7)))
                expect(auth.r).to(equal(U256(from: 16)))
                expect(auth.s).to(equal(U256(from: 32)))
                expect(auth.v).to(equal(U256(from: 1)))
                expect(auth.signer?.BYTES.last).to(equal(0xbb))
            }
            it("treats absent signer as nil") {
                let json = #"""
                {
                  "chainId": "0x01",
                  "address": "0x000000000000000000000000000000000000aaaa",
                  "nonce": "0x0",
                  "r": "0x0", "s": "0x0", "v": "0x0"
                }
                """#.data(using: .utf8)!
                let auth = try! decoder.decode(AuthorizationItem.self, from: json)
                expect(auth.signer).to(beNil())
            }
        }
    }
}

final class Authorization7702Spec: QuickSpec {
    override class func spec() {
        describe("Authorization7702 type") {
            it("stores chainId/address/nonce verbatim") {
                let auth = Authorization7702(chainId: U256(from: 1), address: h160LastByte(0xaa), nonce: 42)
                expect(auth.chainId).to(equal(U256(from: 1)))
                expect(auth.address.BYTES.last).to(equal(0xaa))
                expect(auth.nonce).to(equal(42))
            }
        }
    }
}

final class SignedAuthorizationSpec: QuickSpec {
    override class func spec() {
        describe("SignedAuthorization type") {
            it("stores all six fields verbatim") {
                let sa = SignedAuthorization(
                    chainId: U256(from: 1),
                    address: h160LastByte(0xaa),
                    nonce: 7,
                    r: U256(from: 0x10),
                    s: U256(from: 0x20),
                    v: true
                )
                expect(sa.chainId).to(equal(U256(from: 1)))
                expect(sa.address.BYTES.last).to(equal(0xaa))
                expect(sa.nonce).to(equal(7))
                expect(sa.r).to(equal(U256(from: 0x10)))
                expect(sa.s).to(equal(U256(from: 0x20)))
                expect(sa.v).to(beTrue())
            }

            context("recoverAddress") {
                it("throws notImplemented because secp256k1 isn't wired up") {
                    let sa = SignedAuthorization(
                        chainId: U256(from: 1),
                        address: h160LastByte(0xaa),
                        nonce: 0,
                        r: U256(from: 1),
                        s: U256(from: 1),
                        v: false
                    )
                    expect { try sa.recoverAddress() }
                        .to(throwError(SignedAuthorization.RecoveryError.notImplemented))
                }
            }
        }
    }
}
