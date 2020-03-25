"""
Customisable progressbar decorator for iterators.
Usage:
> using ProgressBars
> for i in ProgressBar(1:10)
> ....
> end
"""
module ProgressBars

using Printf

EIGHTS = Dict(0 => ' ',
              1 => '▏',
              2 => '▎',
              3 => '▍',
              4 => '▌',
              5 => '▋',
              6 => '▊',
              7 => '▉',
              8 => '█')

# Split this because UTF-8 indexing is horrible otherwise
# IDLE = collect("◢◤ ")
IDLE = collect("╱   ")

PRINTING_DELAY = 0.05 * 1e9

export ProgressBar, tqdm, set_description, set_postfix
"""
Decorate an iterable object, returning an iterator which acts exactly
like the original iterable, but prints a dynamically updating
progressbar every time a value is requested.
"""
mutable struct ProgressBar
  wrapped::Any
  total::Int
  current::Int
  width::Int
  start_time::UInt
  last_print::UInt
  description::AbstractString
  postfix::NamedTuple
  mutex::Threads.SpinLock

  function ProgressBar(wrapped::Any; total::Int = -2, width = 100)
    this = new()
    this.wrapped = wrapped
    this.width = width
    this.start_time = time_ns()
    this.last_print = this.start_time - 2 * PRINTING_DELAY
    this.description = ""
    this.postfix = NamedTuple()
    this.mutex = Threads.SpinLock()
    this.current = 0

    if total == -2  # No total given
      try
        this.total = length(wrapped)
      catch 
        this.total = -1
      end
    else
      this.total = total
    end

    return this
  end
end

# Keep the old name as an alias
tqdm = ProgressBar

function format_time(seconds)
  if seconds != Inf
    mins,s  = divrem(round(Int,seconds), 60)
    h, m    = divrem(mins, 60)
  else
    h = 0
    m = Inf
    s = Inf
  end
  if h!=0
    return @sprintf("%02d:%02d:%02d",h,m,s)
  else
    return @sprintf("%02d:%02d",m,s)
  end
end

function display_progress(t::ProgressBar)
  seconds = (time_ns() - t.start_time) * 1e-9
  iteration = t.current - 1

  elapsed = format_time(seconds)
  speed = iteration / seconds
  iterations_per_second = @sprintf("%.1f it/s", speed)

  barwidth = t.width - 2 # minus two for the separators

  postfix_string = postfix_repr(t.postfix)

  # Reset Cursor to beginning of the line
  print("\r")

  if t.description != ""
    barwidth -= length(t.description) + 1
    print(t.description * " ")
  end

  if (t.total <= 0)
    status_string = "$(t.current)it $elapsed [$iterations_per_second$postfix_string]"
    barwidth -= length(status_string) + 1

    print("┣")
    print(join(IDLE[1 + ((i + t.current) % length(IDLE))] for i in 1:barwidth))
    print("┫ ")
    print(status_string)
  else
    ETA = (t.total-t.current) / speed

    percentage_string = string(@sprintf("%.1f%%",t.current/t.total*100))

    eta     = format_time(ETA)
    status_string = "$(t.current)/$(t.total) [$elapsed<$eta, $iterations_per_second$postfix_string]"
    barwidth -= length(status_string) + length(percentage_string) + 1

    cellvalue = t.total / barwidth
    full_cells, remain = divrem(t.current, cellvalue)

    print(percentage_string)
    print("┣")
    print(repeat("█", Int(full_cells)))
    if (full_cells < barwidth)
      part = Int(floor(9 * remain / cellvalue))
      print(EIGHTS[part])
      print(repeat(" ", Int(barwidth - full_cells - 1)))
    end

    print("┫ ")
    print(status_string)
  end
end

function set_description(t::ProgressBar, description::AbstractString)
  t.description = description
end

function set_postfix(t::ProgressBar; postfix...)
  t.postfix = values(postfix)
end

function postfix_repr(postfix::NamedTuple)::AbstractString
  return join(map(tpl -> ", $(tpl[1]): $(tpl[2])", zip(keys(postfix), postfix)))
end

function Base.iterate(iter::ProgressBar)
  iter.start_time = time_ns() - PRINTING_DELAY
  iter.current = 0
  display_progress(iter)
  return iterate(iter.wrapped)
end

function Base.iterate(iter::ProgressBar,s)
  iter.current += 1
  if(time_ns() - iter.last_print > PRINTING_DELAY)
    display_progress(iter)
    iter.last_print = time_ns()
  end
  state = iterate(iter.wrapped,s)
  if state == nothing
    iter.current = iter.total
    display_progress(iter)
    println()
    return nothing
  end
  return state
end
Base.length(iter::ProgressBar) = length(iter.wrapped)
Base.eltype(iter::ProgressBar) = eltype(iter.wrapped)

function Base.unsafe_getindex(iter::ProgressBar, index::Int64)
  """
  Base.unsafe_getindex is used by the `Threads.@threads for ... in ...` macro
  in julia 1.3.
  This wrapper will do weird things when used directly.
  """
  item = Base.unsafe_getindex(iter.wrapped, index)
  lock(iter.mutex)
  iter.current += 1
  if time_ns() - iter.last_print > PRINTING_DELAY
    display_progress(iter)
    iter.last_print = time_ns()
  elseif iter.current == iter.total
    # Reached end of iteration
    display_progress(iter)
    println()
  end
  unlock(iter.mutex)
  return item
end

function Base.firstindex(iter::ProgressBar)
  iter.start_time = time_ns() - PRINTING_DELAY
  iter.current = 0
  display_progress(iter)
  return Base.firstindex(iter.wrapped)
end

function Base.getindex(iter::ProgressBar, index::Int64)
  """
  Base.getindex is used by the `Threads.@threads for ... in ...` macro
  from julia 1.4 on.
  This wrapper will do weird things when used directly.
  """
  item = Base.getindex(iter.wrapped, index)
  lock(iter.mutex)
  iter.current += 1
  if time_ns() - iter.last_print > PRINTING_DELAY
    display_progress(iter)
    iter.last_print = time_ns()
  elseif iter.current == iter.total
    # Reached end of iteration
    display_progress(iter)
    println()
  end
  unlock(iter.mutex)
  return item
end

end # module
