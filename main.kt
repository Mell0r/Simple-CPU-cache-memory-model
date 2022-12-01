const val M = 64
const val N = 60
const val K = 32
var tickCounter = 0
var cacheMisses = 0
var cacheHits = 0

object MemorySimulator {
    private val lineTag = List(32) { mutableListOf(-1, -1) }
    private val modified = List(32) { mutableListOf(false, false) }
    private val lastUsed = MutableList(32) { 0 }

    fun processOperationOnAddress(tag: Int, set: Int, offset: Int, write: Boolean) {
        if (tickCounter % 2 == 1) //cpu waits for 0 clock and sends request to the cache
            tickCounter++

        //cache work:
        if (tag in lineTag[set]) {
            cacheHits += 1 //cache hit
            tickCounter += 12 //time until cache answers
        } else {
            cacheMisses += 1 //cache miss
            tickCounter += 8 //cache sends request to memory
            if (modified[set][1 - lastUsed[set]]) {
                //cache sends to memory write request

                //memory work:
                tickCounter += 200 //time until memory answers
                //memory answered

                tickCounter += 1 //cache waits for 1 clock and listens to answer
                tickCounter += 1 //cache waits for 0 clock, takes the bus, then continues working
            }

            //memory work:
            tickCounter += 200 //time unlit memory answers
            tickCounter += 16 //memory answering
            //memory answered

            tickCounter += 1 //cache listens to answer
            tickCounter += 1 //wait until clock is 0 to cache answer
            modified[set][1 - lastUsed[set]] = false
            lineTag[set][1 - lastUsed[set]] = tag
        }

        if (write)
            modified[set][lineTag[set].indexOf(tag)] = true

        lastUsed[set] = lineTag[set].indexOf(tag)

        //cache answered

        tickCounter += 1 //cpu wait for 1 clock and listens the answer
        tickCounter += 1 //cpu wait for 0 clock, takes the bus, then continues working
    }
}

fun readA(row: Int, col: Int) {
    val j = row * K + col
    MemorySimulator.processOperationOnAddress(j / (16 * 32), (j / 16) % 32, j % 16, false)
}

fun readB(row: Int, col: Int) {
    val j = M * K + (row * N + col) * 2
    MemorySimulator.processOperationOnAddress(j / (16 * 32), (j / 16) % 32, j % 16, false)
}

fun writeC(row: Int, col: Int) {
    val j = M * K + K * N * 2 + (row * N + col) * 4
    MemorySimulator.processOperationOnAddress(j / (16 * 32), (j / 16) % 32, j % 16, true)
}

fun main() {
    tickCounter += 2 //pa init
    tickCounter += 2 //pc init
    for (y in 0 until M) {
        tickCounter += 2 //y init and ++ later

        for (x in 0 until N) {
            tickCounter += 2 //x init and ++ later

            tickCounter += 2 //pb init
            tickCounter += 2 //s init
            for (k in 0 until K) {
                tickCounter += 2 //k init and ++ later

                readA(y, k)
                readB(k, x)

                tickCounter += 12 // += and *
                tickCounter += 2 //pb +=
                tickCounter += 2 //k new iter
            }
            writeC(y, x)

            tickCounter += 2 //x new iter
        }

        tickCounter += 2 //pa +=
        tickCounter += 2 //pc +=
        tickCounter += 2 //y new iter
    }
    tickCounter += 2 //fun exit

    println("Cache requests: ${cacheHits + cacheMisses}")
    println("Cache hits: $cacheHits. Percent of hits: ${cacheHits * 100 / (cacheHits + cacheMisses)}")
    print("Total ticks: ${tickCounter / 2}")
}