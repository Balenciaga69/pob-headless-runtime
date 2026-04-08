std = "luajit"
max_line_length = false
files["tests/**/*.lua"] = {
   globals = {
      "describe",
      "it",
      "before_each",
      "after_each",
      "before",
      "after",
      "pending",
      "assert",
      "PoBHeadless"
   }
}

files["src/compatibility/**/*.lua"] = {
   ignore = {
      "111",
      "113",
      "121",
      "122",
      "211",
      "212",
      "213"
   }
}

globals = {
   "main",
   "launch",
   "buildMode",
   "newBuild",
   "callbacks",
   "wipeTable",
   "modLib",
   "PoBHeadless",
   "common",
   "GetRuntimePath",
   "new",
   "io",
   "os"
}

read_globals = {
   "arg",
   "package",
   "math",
   "string",
   "table",
   "coroutine",
   "debug",
   "bit",
   "jit",
   "utf8"
}

exclude_files = {
   ".tools/**",
   "dist/**",
   "vendor/**",
   "tips/**",
   "**/.mypy_cache/**",
   "manual-scripts/**"
}

ignore = {
   "122",
   "212",
   "213",
   "614"
}
