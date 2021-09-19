import asyncpools
import std/unittest

import std/sugar
import std/asyncdispatch
import std/sequtils

test "it works":
  const
    PoolSize = 4
    InputsCount = 10
    SleepMultiplier = 50
  var
    runningCount = 0
    isReachedPoolSize = false
  let inputs = (1..InputsCount).toSeq

  proc fut(n: int): Future[int] {.async.} =
    inc runningCount
    check runningCount <= PoolSize
    if runningCount == PoolSize:
      isReachedPoolSize = true
    await sleepAsync((inputs.high - n + 1) * SleepMultiplier)
    dec runningCount
    return n
  
  let
    futProcs = inputs.map(n => (() {.closure.} => fut(n)))
    outputs = waitFor asyncPool(futProcs, PoolSize)
  
  check isReachedPoolSize
  check outputs.len == inputs.len
  for x in inputs:
    check outputs.contains(x)

test "failure reporting works":
  proc fut(fail: bool): Future[int] {.async.} =
    if fail:
      raise newException(CatchableError, "fail")
    return 42

  let outputs = waitFor asyncPool(@[
    initFutJob("one", () {.closure.} => fut(false)),
    initFutJob("two", () {.closure.} => fut(true)),
    initFutJob("three", () {.closure.} => fut(false)),
  ], DefaultPoolSize, fbContinue)

  check outputs.values.len == 2
  check outputs.values == @[42, 42]
  check outputs.failures.len == 1
  check outputs.failures == @["two"]
