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
  check inputs == outputs
