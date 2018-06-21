"""
Provides logging functionality for Genie apps.
"""
module Logger

using Lumberjack, Millboard, Dates
using SearchLight

# color mappings for logging levels -- to be used in STDOUT printing
const colors = Dict{String,Symbol}("info" => :gray, "warn" => :yellow, "debug" => :green, "err" => :red, "error" => :red, "critical" => :magenta)

"""
    log(message, level = "info"; showst::Bool = true) :: Nothing
    log(message::Any, level::Any = "info"; showst::Bool = false) :: Nothing
    log(message::String, level::Symbol) :: Nothing

Logs `message` to all configured logs (STDOUT, FILE, etc) by delegating to `Lumberjack`.
Supported values for `level` are "info", "warn", "debug", "err" / "error", "critical".
If `level` is `error` or `critical` it will also dump the stacktrace onto STDOUT.

# Examples
```julia
julia> Logger.log("hello")

2016-12-21T18:38:09.105 - info: hello


julia> Logger.log("hello", "warn")

2016-12-21T18:38:22.461 - warn: hello


julia> Logger.log("hello", "debug")

2016-12-21T18:38:32.292 - debug: hello


julia> Logger.log("hello", "err")

2016-12-21T18:38:38.403 - err: hello
```
"""
function log(message, level::Any = "info"; showst = false) :: Nothing
  message = string(message)
  level = string(level)
  level == "err" && (level = "error")

  if ! isdefined(:SearchLight) || ! isdefined(:SearchLight, :config) || ! SearchLight.config.suppress_output
    println()
    Lumberjack.log(string(level), string(message))
    println()
  end

  if (level == "critical" || level == "error") && showst
    println()
    stacktrace()
  end

  nothing
end
function log(message::String, level::Symbol; showst::Bool = false) :: Nothing
  log(message, level == :err ? "error" : string(level), showst = showst)
end


"""
    self_log(message, level::Union{String,Symbol}) :: Nothing

Basic logging function that does not rely on external logging modules (such as `Lumberjack`).

# Examples
```julia
julia> Logger.self_log("hello", :err)

err 2016-12-21T18:49:00.286
hello

julia> Logger.self_log("hello", :info)

info 2016-12-21T18:49:05.068
hello

julia> Logger.self_log("hello", :debug)

debug 2016-12-21T18:49:11.123
hello
```
"""
function self_log(message, level::Union{String,Symbol}) :: Nothing
  println()
  print_with_color(colors[string(level)], (string(level), " ", string(Dates.now()), "\n")...)
  print_with_color(colors[string(level)], string(message))
  println()

  nothing
end


"""
    truncate_logged_output(output::AbstractString) :: String

Truncates (shortens) output based on `output_length` settings and appends "..." -- to be used for limiting the output length when logging.

# Examples
```julia
julia> Genie.config.output_length
100

julia> Genie.config.output_length = 10
10

julia> Logger.truncate_logged_output("abc " ^ 10)
"abc abc ab..."
```
"""
function truncate_logged_output(output::AbstractString) :: String
  if length(output) > SearchLight.config.output_length
    output = output[1:SearchLight.config.output_length] * "..."
  end

  output
end


"""
    setup_loggers() :: Bool

Sets up default app loggers (STDOUT and per env file loggers) defferring to the `Lumberjack` module.
Automatically invoked.
"""
function setup_loggers() :: Bool
  configure(; modes=["debug", "info", "notice", "warn", "err", "critical", "alert", "emerg"])
  add_truck(LumberjackTruck(stdout, nothing, Dict{Any,Any}(:is_colorized => true)), "console")
  ispath(SearchLight.LOG_PATH) && add_truck(LumberjackTruck("$(joinpath(SearchLight.LOG_PATH, SearchLight.config.app_env)).log", nothing, Dict{Any,Any}(:is_colorized => true)), "file-logger")

  true
end


"""
    empty_log_queue() :: Vector{Tuple{String,Symbol}}

The log queue is used to push log messages in the early phases of framework bootstrap,
when the logger itself is not available. Once the logger is ready, the queue is emptied and the
messages are logged.
Automatically invoked.
"""
function empty_log_queue() :: Vector{Tuple{String,Symbol}}
  for log_message in SearchLight.SEARCHLIGHT_LOG_QUEUE
    log(log_message...)
  end

  empty!(SearchLight.SEARCHLIGHT_LOG_QUEUE)
end


"""
    macro location()

Provides a macro that injects the FILE and the LINE where the logger was invoked.
"""
macro location()
  :(Logger.log(" in $(@__FILE__):$(@__LINE__)", :err))
end

setup_loggers()
empty_log_queue()

end
