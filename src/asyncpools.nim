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

type
  FutProc[T] = () -> Future[T]

template empty(s: untyped): bool =
  s.len == 0

proc asyncPool*[T](futProcs: seq[FutProc[T]]; poolSize = 4): Future[seq[T]] =
  var queue = futProcs.toDeque()

  var resultFut = newFuture[seq[T]]("asyncPool")
  var activeCount = 0
  var doneCount = 0
  var vals: seq[T]

  proc cb(fut: Future[T]) {.closure, gcsafe.}

  proc startOne() =
    debugEcho "top"
    dump queue.len
    let futProc = queue.popFirst()
    let fut = futProc()
    fut.addCallback(cb)
    inc activeCount
    debugEcho "bottom"

  proc cb(fut: Future[T]) =
    let val = fut.read
    debugEcho "a future completed. value: ", val
    vals.add(val)
    inc doneCount
    dec activeCount
    dump (queue.len, futProcs.len)
    if doneCount == futProcs.len:
      debugEcho "all done"
      resultFut.complete(vals)
    elif not queue.empty:
      debugEcho $queue.len & " left to go"
      if activeCount < poolSize:
        startOne()

  for _ in 0..<min(poolSize, futProcs.len):
    startOne()

  resultFut

proc fut(n: int): Future[int] {.async.} =
  debugEcho "sleeping... n = ", n
  # await sleepAsync(n * 1000)
  await sleepAsync((6 - n + 1) * 1000)
  debugEcho "done sleeping. n = ", n
  return n

when isMainModule:
  let futProcs: seq[() -> Future[int]] = @[
    () {.closure.} => fut(1),
    () {.closure.} => fut(2),
    () {.closure.} => fut(3),
    () {.closure.} => fut(4),
    () {.closure.} => fut(5),
    () {.closure.} => fut(6),
  ]
  let x = waitFor asyncPool(futProcs)
  debugEcho "end"
  dump x
