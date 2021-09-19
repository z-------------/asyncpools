# Copyright (C) 2021 Zack Guard
# 
# This file is part of asyncpools.
# 
# asyncpools is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# asyncpools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with asyncpools.  If not, see <http://www.gnu.org/licenses/>.

import std/asyncdispatch
import std/asyncfutures
import std/sugar
import std/deques

export deques # does not compile without this!

type
  AsyncPoolResult*[T, I] = object
    values*: seq[T]
    failures*: seq[I]
  FutProc[T] = () -> Future[T]
  FutJob*[T, I] = object
    futProc: FutProc[T]
    info: I
  FailureBehavior* = enum
    fbContinue
    fbAbort

const
  DefaultPoolSize* = 4
  DefaultFailureBehavior* = fbAbort

template empty(s: untyped): bool =
  s.len == 0

func initFutJob*[T, I](info: I; futProc: FutProc[T]): FutJob[T, I] =
  result.futProc = futProc
  result.info = info

func initAsyncPoolResult[T, I](values: seq[T]; failures: seq[I]): AsyncPoolResult[T, I] =
  result.values = values
  result.failures = failures

proc asyncPool*[T, I](futJobs: seq[FutJob[T, I]]; poolSize = DefaultPoolSize; failureBehavior = DefaultFailureBehavior): Future[AsyncPoolResult[T, I]] =
  var
    queue = futJobs.toDeque()
    resultFut = newFuture[AsyncPoolResult[T, I]]("asyncPool")
    activeCount = 0
    doneCount = 0
    values: seq[T]
    failures: seq[I]

  proc startOne() =
    let
      futJob = queue.popFirst()
      futProc = futJob.futProc
      fut = futProc()

    proc cb(fut: Future[T]) =
      inc doneCount
      dec activeCount

      if fut.failed:
        case failureBehavior
        of fbAbort:
          discard fut.read # trigger exception
        of fbContinue:
          failures.add(futJob.info)
      else:
        let val = fut.read
        values.add(val)

      if doneCount == futJobs.len:
        resultFut.complete(initAsyncPoolResult(values, failures))
      elif not queue.empty:
        if activeCount < poolSize:
          startOne()

    fut.addCallback(cb)
    inc activeCount

  for _ in 0..<min(poolSize, futJobs.len):
    startOne()

  resultFut

proc asyncPool*[T](futProcs: seq[FutProc[T]]; poolSize = DefaultPoolSize; failureBehavior = DefaultFailureBehavior): Future[seq[T]] {.async.} =
  let futJobs = futProcs.map(proc (futProc: FutProc[T]): FutJob[int, T] =
    initFutJob(0, futProc)
  )
  let asyncPoolResult = await asyncPool(futJobs, poolSize, failureBehavior)
  return asyncPoolResult.values
