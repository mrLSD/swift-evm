[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift CI](https://github.com/mrLSD/evm-swift/actions/workflows/swift.yaml/badge.svg)](https://github.com/mrLSD/evm-swift/actions/workflows/swift.yaml)
[![codecov](https://codecov.io/gh/mrLSD/evm-swift/graph/badge.svg?token=1uc0niBI3c)](https://codecov.io/gh/mrLSD/evm-swift)
[![SwiftLint CI](https://img.shields.io/badge/SwiftLint-CI-blue.svg)](https://github.com/realm/SwiftLint)

<div style="text-align: center;">
    <h1>mrLSD<code>/evm-swift</code></h1>
</div>



Introducing blazinly fast implementation of the Ethereum Virtual Machine (EVM), entirely written in pure Swift. Swift EVM aims to provide developers with a flexible and efficient tool for integrating the EVM into various environments.

Наибольшим приоритетом является:
- максимальная скорость и производительность
- безопасность и надежность
- расширяемость и поддерживаемость кода

Для достижения этих целей критические участки кода реализованы с акцентом на 
максимальную производительность. Для обеспечения безопасности, надежности,
предсказуемости - мы стараемся покрыть максимально тестами приближаясь к 100%
покрытию тестами - логики EVM и его функциональных частей. 

Также для development flow используются: SwiftLint, swiftformat

## Текущий статус

- [x] EVM Machine
- [x] EVM Core (реализовано на 90%)
- [ ] EVM Runtie (in progress)
- [ ] Berling hard fork
- [ ] London hard fork
- [ ] Shanghai hard fork
- [ ] Cancun hard fork
- [ ] Prague hard fork

### Планы по интеграции с блокчейн

- NEAR Protocol

## Project Goal:

Develop a universal Swift-based EVM implementation that allows developers to embed Ethereum smart contract execution directly into their applications and services.

### Key Integration Environments:

- Embedded Systems: Implement blockchain capabilities on resource-constrained devices.
- WebAssembly (WASM): Run the EVM within web browsers and server-side applications with high performance and portability.
- Mobile and Desktop Applications: Integrate decentralized functionalities into iOS, macOS, and other Swift-supported platforms.
- Network Services: Embed the EVM into backend services for processing blockchain transactions and executing smart contracts.

### Benefits for Developers:

- Pure Swift Implementation: Leverage the performance and safety advantages of Swift, ensuring seamless integration with existing Swift projects.
- Cross-Platform Support: Deploy the EVM across different platforms without the need for external dependencies or complex language bindings.
- Open Source: Join the community, contribute, and influence the project’s development.
- Flexibility and Extensibility: Adapt and extend the EVM’s functionality to meet the specific requirements of your projects.

We invite developers and enthusiasts interested in blockchain, Ethereum, and Swift to join this project. Together, we can expand the possibilities of using Ethereum smart contracts across various platforms and applications.

## [LICENSE: MIT](LICENSE)