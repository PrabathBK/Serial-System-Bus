# bus_m2_s3 Simple Testbench - Test Descriptions

**Testbench:** `tb/tb_bus_m2_s3_simple.sv`  
**Run Script:** `sim/run_bus_m2_s3_simple_test.sh`  
**DUT:** `rtl/core/bus_m2_s3.v` (2-master, 3-slave bus system)

---

## Test 1: Reset Test

**Purpose:** Verify all bus control signals initialize to correct reset states

**What it tests:**
- Bus grant signals (`m1_bgrant`, `m2_bgrant`) = 0 (no masters granted)
- Split transaction signals (`m1_split`, `m2_split`) = 0 (no split requests)
- Data ready signals (`m1_dready`, `m2_dready`) = 1 (masters ready for new transactions)

**Expected Result:** All control signals in known safe state after reset

**Why it matters:** Ensures system starts in predictable state, preventing spurious bus grants or split transactions on power-up

---

## Test 2: Single Master Write + Read-Back

**Purpose:** Test basic single-master operation with write and read-back verification

**What it tests:**
- Master 1 writes `0xAA` to Slave 1 at address `0x0100`
- Master 1 reads back from same address
- Serial data transmission (address + data sent bit-by-bit)
- Memory write/read functionality
- Transaction completion handshake (`dvalid`/`dready`)

**Key Verification Points:**
- Write data correctly transmitted through serial bus
- Data properly stored in slave memory (BRAM)
- Read operation retrieves correct data
- `dready` signal correctly indicates transaction start/completion

**Expected Result:** Read-back value matches written value (`0xAA`)

**Why it matters:** Validates core bus protocol for single-master scenario (most common case)

---

## Test 2a: Single Master Read-Only

**Purpose:** Test read-only operation without prior write in same test

**What it tests:**
- Master 1 reads from Slave 1 at address `0x0100` (written in Test 2)
- Verifies read operation works independently
- Confirms data persistence across tests
- Validates read-only transaction flow (no write phase)

**Key Verification Points:**
- Read transaction executes without preceding write
- Memory contents persist between tests
- Read data matches previously written value
- State machine correctly handles read-only mode

**Expected Result:** Read value = `0xAA` (data from Test 2 persists)

**Why it matters:** Many real-world scenarios involve reading pre-initialized memory (bootloader ROM, configuration registers) without prior writes

---

## Test 3: Dual Master Request (Priority Arbitration)

**Purpose:** Test concurrent master requests and priority-based arbitration

**What it tests:**
- Master 1 writes `0x55` to Slave 1 at `0x0200` 
- Master 2 writes `0x77` to Slave 2 at `0x1100`
- Both masters assert `breq` simultaneously (using `fork`/`join`)
- Arbiter grants bus to M1 first (higher priority)
- Arbiter grants bus to M2 after M1 completes
- Both transactions complete successfully
- Read-back verification for both writes

**Key Verification Points:**
- Arbiter correctly prioritizes M1 over M2
- M2 transaction waits (doesn't corrupt M1 data)
- Both masters eventually get bus access
- No data corruption or bus contention

**Expected Result:** M1 read-back = `0x55`, M2 read-back = `0x77`

**Why it matters:** Proves arbiter prevents bus conflicts and enforces priority policy in multi-master system

---

## Test 4: Split Transaction (Slow Slave Support)

**Purpose:** Test split transaction protocol for slaves with long latencies

**What it tests:**
- Master 1 writes `0xBB` to Slave 3 (split-capable) at `0x2050`
- Slave 3 asserts `split` signal during read (simulating slow memory)
- Arbiter releases bus while S3 fetches data
- Arbiter grants bus back to S3 when data ready
- Master 1 reads back split transaction result

**Key Verification Points:**
- Split signal properly asserted by slave
- Arbiter recognizes split request and releases bus
- Bus available for other transactions during split wait
- Split transaction resumes and completes correctly
- Data integrity maintained across split phases

**Expected Result:** Read-back value matches written value (`0xBB`) despite split transaction

**Why it matters:** Enables efficient bus utilization when slow slaves (external DRAM, flash) would otherwise block fast masters

---

## Test Execution Details

**Total Runtime:** ~44µs simulation time  
**Clock Period:** 10ns (100 MHz)  
**Memory Clearing:** First 41µs (4100 cycles) clears slave BRAMs to 0x00  

**Total Tests:** 5  
**All tests PASS** ✓

**Waveform Output:** `tb_bus_m2_s3_simple.vcd` (viewable with GTKWave)
