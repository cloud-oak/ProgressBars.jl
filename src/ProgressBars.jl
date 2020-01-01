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

PRINTING_DELAY = 0.05 * 1e9

export ProgressBar, tqdm, set_description
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
  mutex::Threads.SpinLock

  function ProgressBar(wrapped::Any; total::Int = -1, width = 100)
    this = new()
    this.wrapped = wrapped
    this.width = width
    this.start_time = time_ns()
    this.last_print = this.start_time - 2 * PRINTING_DELAY
    this.description = ""
    this.mutex = Threads.SpinLock()
    this.current = 0

    if total == -1  # No total given
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
    h=0;m=Inf;s=Inf
  end
  if h!=0
    return @sprintf("%02d:%02d:%02d",h,m,s)
  else
    return @sprintf("%02d:%02d",m,s)
  end
end

function display_progress(t::ProgressBar)
  if (t.total <= 0)
    percentage_string = string(t.current)
  else
    if (t.current > 0)
      iteration = t.current - 1
      seconds   = (time_ns() - t.start_time) * 1e-9
      speed     = iteration / seconds
      ETA       = (t.total-t.current) / speed
    else
      ETA = Inf; speed = 0.0; seconds = Inf
    end

    percentage_string = string(@sprintf("%.2f%%",t.current/t.total*100))
  end

  elapsed = format_time(seconds)
  eta     = format_time(ETA)
  iterations_per_second = @sprintf("%.2f it/s", speed)

  status_string = "$(t.current)/$(t.total) $elapsed<$eta, $iterations_per_second]"
  width = t.width - length(percentage_string) - length(status_string) - 2
  if t.description != ""
    width -= length(t.description) + 1
    print(t.description * " ")
  end

  print("\r")
  print(percentage_string)
  print("┣")

  if (t.total <= 0)
    offset = t.current % 10
    print(repeat(" ", offset))
    segments, remain = divrem(width - offset, 10)
    print(repeat("/         ", Int(segments)))
    print(repeat(" ", Int(remain)))
  else
    cellvalue = t.total / width
    full_cells, remain = divrem(t.current, cellvalue)
    print(repeat("█", Int(full_cells)))

    if (full_cells < width)
      part = Int(floor(8 * remain / cellvalue))
      print(EIGHTS[part])
      print(repeat(" ", Int(width - full_cells - 1)))
    end
  end
  print("┫ ")

  print(status_string)

end

function set_description(t::ProgressBar, description::AbstractString)
  t.description = description
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
  if state===nothing
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
  Base.unsafe_getindex is used by the `Threads.@threads for ... in ...` macro.
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

end # module
