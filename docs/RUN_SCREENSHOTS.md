# EDA Playground Run Screenshots

This page collects screenshot evidence from the EDA Playground simulations.
Each entry should show the relevant run configuration and the resulting VCS/UVM
output, including the test name, configuration, seed when available, scoreboard
summary, coverage summary, and any assertion or checker failures.

Screenshots belong in `docs/screenshots/`.

## Clean Test Runs

| Test                     | Run options                                     | Screenshot                                                          |
| ------------------------ | ----------------------------------------------- | ------------------------------------------------------------------- |
| `smoke_test`             | `+UVM_TESTNAME=smoke_test +num_txns=5`          | `![smoke_test](screenshots/smoke_test.png)`                         |
| `mesi_walk_test`         | `+UVM_TESTNAME=mesi_walk_test`                  | `![mesi_walk_test](screenshots/mesi_walk_test.png)`                 |
| `pingpong_test`          | `+UVM_TESTNAME=pingpong_test +num_txns=30`      | `![pingpong_test](screenshots/pingpong_test.png)`                   |
| `eviction_test`          | `+UVM_TESTNAME=eviction_test +num_txns=30`      | `![eviction_test](screenshots/eviction_test.png)`                   |
| `upgrade_race_test`      | `+UVM_TESTNAME=upgrade_race_test`               | `![upgrade_race_test](screenshots/upgrade_race_test.png)`           |
| `producer_consumer_test` | `+UVM_TESTNAME=producer_consumer_test`          | `![producer_consumer_test](screenshots/producer_consumer_test.png)` |
| `false_sharing_test`     | `+UVM_TESTNAME=false_sharing_test +num_txns=30` | `![false_sharing_test](screenshots/false_sharing_test.png)`         |
| `store_streak_test`      | `+UVM_TESTNAME=store_streak_test`               | `![store_streak_test](screenshots/store_streak_test.png)`           |
| `read_mostly_test`       | `+UVM_TESTNAME=read_mostly_test +num_txns=30`   | `![read_mostly_test](screenshots/read_mostly_test.png)`             |
| `shared_region_test`     | `+UVM_TESTNAME=shared_region_test +num_txns=30` | `![shared_region_test](screenshots/shared_region_test.png)`         |
| `random_test`            | `+UVM_TESTNAME=random_test`                     | `![random_test](screenshots/random_test.png)`                       |
| `regression_test`        | `+UVM_TESTNAME=regression_test`                 | `![regression_test](screenshots/regression_test.png)`               |

## Bug Injection Runs

These runs intentionally contain one RTL mutation. The expected result is a
failure, not a clean pass. `BUG_3` is expected to report scoreboard errors while
still exiting with code 0; the other four mutations are expected to trigger an
illegal coverage bin and exit with code 1.

| Mutation | Run options                                                  | Expected evidence                     | Screenshot                        |
| -------- | ------------------------------------------------------------ | ------------------------------------- | --------------------------------- |
| `BUG_1`  | `+define+BUG_1` + `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_mesi` illegal bin `m_to_e`        | `![BUG_1](screenshots/bug_1.png)` |
| `BUG_2`  | `+define+BUG_2` + `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_share` illegal bin `ms`           | `![BUG_2](screenshots/bug_2.png)` |
| `BUG_3`  | `+define+BUG_3` + `+UVM_TESTNAME=eviction_test +num_txns=30` | Golden-memory mismatches; exit code 0 | `![BUG_3](screenshots/bug_3.png)` |
| `BUG_4`  | `+define+BUG_4` + `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_mesi` illegal bin `dirty_dropped` | `![BUG_4](screenshots/bug_4.png)` |
| `BUG_5`  | `+define+BUG_5` + `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_share` illegal bin `se`           | `![BUG_5](screenshots/bug_5.png)` |

## Alternate Geometry

| Geometry        | Compile options                                 | Run options                                | Screenshot                                                              |
| --------------- | ----------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------- |
| `4-way / 8-set` | `+define+CFG_NUM_WAYS=4 +define+CFG_NUM_SETS=8` | `+UVM_TESTNAME=eviction_test +num_txns=30` | `![4-way 8-set eviction_test](screenshots/eviction_test_4way_8set.png)` |
