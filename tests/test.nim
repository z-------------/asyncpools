import asyncpools
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
    isReachedPoolSize = false
  let inputs = (1..InputsCount).toSeq
  let inputsHigh = inputs.high

  proc fut(n: int): Future[int] {.async.} =
    inc runningCount
    check runningCount <= PoolSize
    if runningCount == PoolSize:
      isReachedPoolSize = true
    await sleepAsync((inputsHigh - n + 1) * SleepMultiplier)
    dec runningCount
    return n

  let
    futProcs = inputs.mapIt(() => fut(it))
    outputs = waitFor asyncPool(futProcs, PoolSize)

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
