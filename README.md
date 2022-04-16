# asyncpools

## Example

```nim
import pkg/asyncpools

import std/sugar
import std/sequtils
import std/times
import std/strformat

const Count = 4

var runningCount = 0

let startTime = cpuTime()

proc doAsyncStuff(n: int): Future[string] {.async.} =
  inc runningCount
  echo &"{n} began at {cpuTime() - startTime :.2f}; {runningCount} jobs are running"
  await sleepAsync((Count - n) * 500)
  echo &"{n} ended at {cpuTime() - startTime :.2f}; {runningCount} jobs are running"
  dec runningCount
  return $n

let
  inputs = collect(for i in 0..<Count: i)
  outputs = waitFor asyncPool(inputs.mapIt(() => doAsyncStuff(it)), 2)
echo outputs

# Possible output:
# 0 began at 0.00; 1 jobs are running
# 1 began at 0.00; 2 jobs are running
# 1 ended at 1.50; 2 jobs are running
# 2 began at 1.50; 2 jobs are running
# 0 ended at 2.00; 2 jobs are running
# 3 began at 2.00; 2 jobs are running
# 3 ended at 2.50; 2 jobs are running
# 2 ended at 2.50; 1 jobs are running
# @["0", "1", "2", "3"]
```
