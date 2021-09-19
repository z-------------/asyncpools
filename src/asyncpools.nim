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
  FutProc[T] = () -> Future[T]

template empty(s: untyped): bool =
  s.len == 0

proc asyncPool*[T](futProcs: seq[FutProc[T]]; poolSize = 4): Future[seq[T]] =
  var
    queue = futProcs.toDeque()
    resultFut = newFuture[seq[T]]("asyncPool")
    activeCount = 0
    doneCount = 0
    vals: seq[T]

  proc cb(fut: Future[T]) {.closure, gcsafe.}

  proc startOne() =
    let
      futProc = queue.popFirst()
      fut = futProc()
    fut.addCallback(cb)
    inc activeCount

  proc cb(fut: Future[T]) =
    let val = fut.read
    vals.add(val)
    inc doneCount
    dec activeCount
    if doneCount == futProcs.len:
      resultFut.complete(vals)
    elif not queue.empty:
      if activeCount < poolSize:
        startOne()

  for _ in 0..<min(poolSize, futProcs.len):
    startOne()

  resultFut
