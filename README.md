# asyncpools

[![Pipeline status](https://gitlab.com/z-------------/asyncpools/badges/master/pipeline.svg)](https://gitlab.com/z-------------/asyncpools/pipelines)

## Example

```nim
import pkg/asyncpools
import std/[
  asyncdispatch,
  monotimes,
  sequtils,
  strformat,
  sugar,
  times,
]

proc elapsedSince(startTime: MonoTime): float =
  (getMonoTime() - startTime).inMilliseconds / 1000

const Count = 4

var runningCount = 0

let startTime = getMonoTime()

proc doAsyncStuff(n: int): Future[string] {.async.} =
  inc runningCount
  echo &"{n} began at {elapsedSince(startTime) :.2f}; {runningCount} jobs are running"
  await sleepAsync((Count - n) * 500)
  dec runningCount
  echo &"{n} ended at {elapsedSince(startTime) :.2f}; {runningCount} jobs are running"
  return $n

let
  inputs = (0..<Count).toSeq
  outputs = waitFor asyncPool(inputs.mapIt(() => doAsyncStuff(it)), 2)
echo outputs

# Possible output:
# 0 began at 0.00; 1 jobs are running
# 1 began at 0.00; 2 jobs are running
# 1 ended at 1.50; 1 jobs are running
# 2 began at 1.50; 2 jobs are running
# 0 ended at 2.00; 1 jobs are running
# 3 began at 2.00; 2 jobs are running
# 3 ended at 2.50; 1 jobs are running
# 2 ended at 2.50; 0 jobs are running
# @["0", "1", "2", "3"]
```
