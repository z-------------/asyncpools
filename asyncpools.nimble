# Package

version       = "0.0.3"
author        = "Zack Guard"
description   = "Async pools"
license       = "GPL-3.0-or-later"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.8"


# Tasks

task tag, "Create a git annotated tag with the current nimble version":
  let tagName = "v" & version
  exec "git tag -a '" & tagName & "' -m '" & tagName & "'"
