@testable import Interpreter
import Nimble
import PrimitiveTypes
import Quick

final class InstructionCallDataSizeSpec: QuickSpec {
    @MainActor
    static let machineLowGas = TestMachine.machine(opcode: Opcode.CALLDATASIZE, gasLimit: 1)

    override class func spec() {
        describe("Instruction CALLDATASIZE") {
            it("data size = 0") {
                var m = TestMachine.machine(data: [], opcode: Opcode.CALLDATASIZE, gasLimit: 10)

                m.evalLoop()
                expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                let result = m.stack.pop()
                expect(result).to(beSuccess { value in
                    expect(value).to(equal(U256(from: 0)))
                })

                expect(m.stack.length).to(equal(0))
                expect(m.gas.remaining).to(equal(8))
            }
            /*
             it("data size = 5") {
                 // Создаем машину с опкодом CALLDATASIZE, достаточным газом и данными вызова размером 5 байт
                 var m = TestMachine.machine(opcode: Opcode.CALLDATASIZE, gasLimit: 10)
                 let callData: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
                 m.data = callData // Устанавливаем данные вызова

                 m.evalLoop()

                 // Ожидаем успешное завершение
                 expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                 // Проверяем результат в стеке
                 let result = m.stack.pop()
                 expect(result).to(beSuccess { value in
                     // Размер данных должен быть 5
                     expect(value).to(equal(U256(from: 5)))
                 })

                 // Стек должен быть пуст
                 expect(m.stack.length).to(equal(0))
                 // Газ: 10 (начальный) - 2 (BASE cost) = 8
                 expect(m.gas.remaining).to(equal(8))
             }

             it("multiple CALLDATASIZE with data size = 3") {
                 // Создаем машину с ДВУМЯ опкодами CALLDATASIZE, достаточным газом и данными вызова размером 3 байта
                 var m = TestMachine.machine(opcodes: [Opcode.CALLDATASIZE, Opcode.CALLDATASIZE], gasLimit: 10)
                 let callData: [UInt8] = [0xaa, 0xbb, 0xcc]
                 m.data = callData // Устанавливаем данные вызова

                 m.evalLoop()

                 // Ожидаем успешное завершение
                 expect(m.machineStatus).to(equal(.Exit(.Success(.Stop))))

                 // Проверяем оба результата в стеке (они добавляются в обратном порядке)
                 for _ in 0 ..< 2 {
                     let result = m.stack.pop()
                     expect(result).to(beSuccess { value in
                         // Каждый вызов CALLDATASIZE должен вернуть размер 3
                         expect(value).to(equal(U256(from: 3)))
                     })
                 }

                 // Стек должен быть пуст
                 expect(m.stack.length).to(equal(0))
                 // Газ: 10 (начальный) - 2 * 2 (BASE cost за каждый CALLDATASIZE) = 6
                 expect(m.gas.remaining).to(equal(6))
             }

             it("with OutOfGas result") {
                 // Используем машину с низким лимитом газа (gasLimit = 1)
                 // Важно: machineLowGas уже создана с opcode CALLDATASIZE и пустыми данными
                 var m = Self.machineLowGas

                 m.evalLoop()

                 // Ожидаем ошибку нехватки газа
                 expect(m.machineStatus).to(equal(.Exit(.Error(.OutOfGas))))
                 // Стек должен остаться пустым, т.к. газ кончился до stackPush
                 expect(m.stack.length).to(equal(0))
                 // Газ не должен был быть успешно списан, остается начальное значение
                 expect(m.gas.remaining).to(equal(1))
             }

             it("check stack overflow") {
                 // Создаем машину с CALLDATASIZE, достаточным газом
                 var m = TestMachine.machine(opcode: Opcode.CALLDATASIZE, gasLimit: 10)
                 m.data = [0xff] // Неважно какие данные, главное что есть

                 // Заполняем стек до предела *перед* выполнением
                 for i in 0 ..< m.stack.limit {
                     // Используем разные значения, чтобы убедиться, что они не влияют на сам тест переполнения
                     let _ = m.stack.push(value: U256(from: UInt64(i)))
                 }

                 m.evalLoop()

                 // Ожидаем ошибку переполнения стека
                 // Газ списывается ДО попытки записи в стек
                 expect(m.machineStatus).to(equal(.Exit(.Error(.StackOverflow))))
                 // Длина стека должна остаться на пределе
                 expect(m.stack.length).to(equal(m.stack.limit))
                 // Газ: 10 (начальный) - 2 (BASE cost) = 8. Газ списывается до проверки стека.
                 expect(m.gas.remaining).to(equal(8))
             }
             */
        }
    }
}
