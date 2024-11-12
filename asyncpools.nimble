# Package

version       = "0.0.13"
author        = "Zack Guard"
description   = "Async-based limited concurrency"
license       = "GPL-3.0-or-later"
srcDir        = "."

# Dependencies

requires "nim >= 1.6.20"
taskRequires "test", "chronos >= 4.0.0"
