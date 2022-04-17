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

export asyncdispatch
when NimMinor <= 4:
  export deques

const
  DefaultPoolSize* = 4

template empty(s: untyped): bool =
  s.len == 0

proc asyncPool*[T](futProcs: seq[() -> Future[T]]; poolSize = DefaultPoolSize): Future[seq[T]] | Future[void] =
  when T is void:
    type ResultType = void
  else:
    type ResultType = seq[T]

  var
    queue = futProcs.toDeque()
    resultFut = newFuture[ResultType]("asyncPool")
    activeCount = 0
    doneCount = 0
    curIdx = 0
  when T isnot void:
    var values = newSeq[T](queue.len)

  proc startOne() =
    when T isnot void:
      let idx = curIdx

    proc cb(fut: Future[T]) =
      when T isnot void:
        let val = fut.read
        values[idx] = val
      inc doneCount
      dec activeCount
      if doneCount == futProcs.len:
        when T is void:
          resultFut.complete()
        else:
          resultFut.complete(values)
      elif not queue.empty:
        if activeCount < poolSize:
          startOne()

    let
      futProc = queue.popFirst()
      fut = futProc()
    fut.addCallback(cb)
    inc activeCount
    inc curIdx

  for _ in 0..<min(poolSize, futProcs.len):
    startOne()

  resultFut
