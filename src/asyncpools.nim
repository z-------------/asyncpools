# Copyright (C) 2021-2023 Zack Guard
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

type
  PoolStateRef[T] = ref object
    curIdx: int
    when T isnot void:
      values: seq[T]
    else:
      discard
  GcsafeFutProc[T] = proc (): Future[T] {.gcsafe.}
  FutProc[T] = proc (): Future[T]

func new[T](_: typedesc[PoolStateRef[T]]; valuesLen: int): PoolStateRef[T] {.raises: [].} =
  result = PoolStateRef[T]()
  when T isnot void:
    result.values = newSeq[T](valuesLen)

proc worker[T](futProcs: seq[GcsafeFutProc[T]] or seq[FutProc[T]]; state: PoolStateRef[T]) {.async.} =
  while state.curIdx < futProcs.len:
    let idx = state.curIdx
    inc state.curIdx
    let futProc = futProcs[idx]

    when T isnot void:
      state.values[idx] = await futProc()
    else:
      await futProc()

proc asyncPool*[T](futProcs: seq[GcsafeFutProc[T]] or seq[FutProc[T]]; poolSize: Positive = DefaultPoolSize): Future[seq[T]] or Future[void] =
  when T is void:
    type ResultType = void
  else:
    type ResultType = seq[T]

  var
    resultFut = newFuture[ResultType]("asyncPool")
    doneCount = 0
    state = PoolStateRef[T].new(futProcs.len)

  template finish =
    when T is void:
      resultFut.complete()
    else:
      resultFut.complete(state.values)

  if futProcs.len == 0:
    finish()
  else:
    let workerCount = min(poolSize, futProcs.len)
    var workerFuts = newSeq[Future[void]](workerCount)
    for i in 0 ..< workerCount:
      workerFuts[i] = worker(futProcs, state)
      capture i:
        workerFuts[i].addCallback do (_: CallbackArg[void]):
          if not resultFut.finished:
            if workerFuts[i].failed:
              resultFut.fail(workerFuts[i].error)
            else:
              inc doneCount
              if doneCount >= workerCount:
                finish()

  resultFut
