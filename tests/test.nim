import pkg/asyncpools
import std/unittest

import std/sequtils
import std/sets
import std/sugar

const
  asyncBackend {.strdefine.} = "asyncdispatch"

when asyncBackend == "chronos":
  import pkg/chronos
else:
  import std/asyncdispatch

test "it works":
  const
    PoolSize = 4
    InputsCount = 10
    SleepMultiplier = 50
  var
    runningCount = 0
    maxRunningCount = 0
    isReachedPoolSize = false
  let inputs = (1..InputsCount).toSeq
  let inputsHigh = inputs.high

  proc fut(n: int): Future[int] {.async.} =
    inc runningCount
    maxRunningCount = max(runningCount, maxRunningCount)
    if runningCount == PoolSize:
      isReachedPoolSize = true
    await sleepAsync((inputsHigh - n + 1) * SleepMultiplier)
    dec runningCount
    return n

  let
    futProcs = inputs.mapIt(() => fut(it))
    outputs = waitFor asyncPool(futProcs, PoolSize)

  check maxRunningCount == PoolSize
  check isReachedPoolSize
  check inputs == outputs

test "it supports void futures":
  const
    PoolSize = 4
    InputsCount = 10
  var record: HashSet[int]
  let inputs = (1..InputsCount).toSeq

  proc fut(n: int): Future[void] {.async.} =
    {.cast(gcsafe).}:
      record.incl(n)

  let futProcs = inputs.mapIt(() => fut(it))
  waitFor asyncPool(futProcs, PoolSize)

  check record == inputs.toHashSet

test "it works with empty input":
  proc fut(n: int): Future[string] {.async.} =
    discard

  let futProcs = newSeq[int]().mapIt(() => fut(it))
  let outputs = waitFor asyncPool(futProcs, 4)
  check outputs == newSeq[string]()

test "it handles errors":
  type MyError = object of CatchableError

  proc fut(n: int) {.async.} =
    raise newException(MyError, ":(")

  let futProcs = (1..8).toSeq.mapIt(() => fut(it))
  expect MyError:
    waitFor asyncPool(futProcs, 4)

test "it really handles errors":
  type MyError = object of CatchableError

  proc fut(n: int) {.async.} =
    await sleepAsync(100)
    if n == 7:
      raise newException(MyError, ":(")

  let futProcs = (1..8).toSeq.mapIt(() => fut(it))
  expect MyError:
    waitFor asyncPool(futProcs, 4)

test "it is gcsafe when the future procs are gcsafe":
  proc fut(n: int): Future[string] {.async, gcsafe.} =
    return $n

  proc run(): Future[seq[string]] {.async, gcsafe.} =
    let futProcs = [1, 2].mapIt(() => fut(it))
    return await asyncPool(futProcs, 2)

  let outputs = waitFor run()
  check outputs == ["1", "2"]

test "it works with non-closures":
  proc gcsafeFutProc(): Future[void] {.nimcall.} =
    let fut = newFuture[void]()
    fut.complete()
    fut

  waitFor asyncPool(@[gcsafeFutProc])
