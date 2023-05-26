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

const
  asyncBackend {.strdefine.} = "asyncdispatch"

when asyncBackend == "chronos":
  import pkg/chronos
  type CallbackArg[T] = pointer
else:
  import std/[
    asyncdispatch,
    asyncfutures,
  ]
  type CallbackArg[T] = Future[T]

import std/sugar

const
  DefaultPoolSize* = 4

proc asyncPool*[T](futProcs: seq[() -> Future[T]]; poolSize: Positive = DefaultPoolSize): Future[seq[T]] or Future[void] =
  when T is void:
    type ResultType = void
  else:
    type ResultType = seq[T]

  var
    resultFut = newFuture[ResultType]("asyncPool")
    activeCount = 0
    doneCount = 0
    curIdx = 0
  when T isnot void:
    var values = newSeq[T](futProcs.len)

  template finish =
    when T is void:
      resultFut.complete()
    else:
      resultFut.complete(values)

  proc startOne() {.gcsafe.} =
    when T isnot void:
      let idx = curIdx

    let futProc = futProcs[curIdx]
    {.cast(gcsafe).}:
      let fut = futProc()

    proc cb(arg: CallbackArg[T]) {.gcsafe.} =
      when T isnot void:
        try:
          values[idx] = fut.read()
        except CatchableError as e:
          resultFut.fail(e)
      inc doneCount
      dec activeCount
      if doneCount == futProcs.len:
        finish()
      elif curIdx < futProcs.len:
        if activeCount < poolSize:
          startOne()

    inc activeCount
    inc curIdx
    fut.addCallback(cb)

  if futProcs.len > 0:
    for _ in 0..<min(poolSize, futProcs.len):
      startOne()
  else:
    finish()

  resultFut
