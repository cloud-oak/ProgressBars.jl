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

export ProgressBar, tqdm, set_description, set_postfix, set_multiline_postfix
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
  fixwidth::Bool
  leave::Bool
  start_time::UInt
  last_print::UInt
  postfix::NamedTuple
  extra_lines::Int
  printing_delay::UInt
  unit::AbstractString
  iter_unit::AbstractString
  unit_scale::Bool
  description::AbstractString
  multilinepostfix::AbstractString
  mutex::Threads.SpinLock

  function ProgressBar(wrapped::Any;
                       total::Int=-2,
                       width::Union{UInt, Nothing}=nothing,
                       leave::Bool=true,
                       unit::AbstractString="",
                       unit_scale::Bool=true,
                       printing_delay::Number=0.05)
    this = new()
    this.wrapped = wrapped
    if width == nothing
        this.width = displaysize(stdout)[2]
        this.fixwidth = false
    else
        this.width = width
        this.fixwidth = true
    end
    this.leave = leave
    this.printing_delay = trunc(UInt, printing_delay * 1e9)
    this.start_time = time_ns()
    this.last_print = this.start_time - 2 * this.printing_delay
    this.postfix = NamedTuple()
    this.description = ""
    this.unit = unit
    this.iter_unit = (unit == "") ? "it" : unit
    this.unit_scale = unit_scale
    this.multilinepostfix = ""
    this.extra_lines = 0
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
  if isfinite(seconds)
    mins,s  = divrem(round(Int, seconds), 60)
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

function format_amount(amount::Number, unit::AbstractString, unit_scale::Bool)
  if unit_scale
    if amount >= 1_000_000_000
      return @sprintf("%.1fG%s", amount / 1_000_000_000., unit)
    elseif amount >= 1_000_000
      return @sprintf("%.1fM%s", amount / 1_000_000., unit)
    elseif amount >= 1_000
      return @sprintf("%.1fk%s", amount / 1_000., unit)
    end
    # We can fall through to the default case for amount < 1000 
  end
  return @sprintf("%d%s", amount, unit)
end

function display_progress(t::ProgressBar)
  seconds = (time_ns() - t.start_time) * 1e-9
  iteration = t.current - 1

  elapsed = format_time(seconds)
  speed = iteration / seconds
  if seconds == 0
    # Dummy value of 1 it/s if no time has elapsed
    speed = 1
  end

  if speed >= 1
    iterations_per_second = format_amount(speed, "$(t.iter_unit)/s", t.unit_scale)
  else
    # TODO: This might fail if speed == 0
    iterations_per_second = format_amount(1 / speed, "s/$(t.iter_unit)", t.unit_scale)
  end

  barwidth = t.width - 2 # minus two for the separators

  postfix_string = postfix_repr(t.postfix)

  # Reset Cursor to beginning of the line
  for line in 1:t.extra_lines
    move_up_1_line()
  end
  go_to_start_of_line()

  if t.description != ""
    barwidth -= length(t.description) + 1
    print(t.description * " ")
  end

  if (t.total <= 0)
    current = format_amount(t.current, t.iter_unit, t.unit_scale)
    status_string = "$(current) $elapsed [$iterations_per_second$postfix_string]"
    barwidth -= length(status_string) + 1
    if barwidth < 0
      barwidth = 0
    end

    print("┣")
    print(join(IDLE[1 + ((i + t.current) % length(IDLE))] for i in 1:barwidth))
    print("┫ ")
    print(status_string)
  else
    ETA = (t.total-t.current) / speed

    percentage_string = string(@sprintf("%.1f%%",t.current/t.total*100))

    eta = format_time(ETA)
    current = format_amount(t.current, t.unit, t.unit_scale)   
    total   = format_amount(t.total, t.unit, t.unit_scale)   
    status_string = "$(current)/$(total) [$elapsed<$eta, $iterations_per_second$postfix_string]"

    barwidth -= length(status_string) + length(percentage_string) + 1
    if barwidth < 0
      barwidth = 0
    end

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
  multiline_postfix_string = newline_to_spaces(t.multilinepostfix, t.width)
  t.extra_lines = ceil(Int, length(multiline_postfix_string) / t.width) + 1
  print(multiline_postfix_string)
  println()
end

function clear_progress(t::ProgressBar)
  # Reset cursor, fill width with empty spaces, and then reset again
  print("\r", " "^t.width, "\r")
  for line in 1:(t.extra_lines)
    erase_line()
    move_up_1_line()
  end
  erase_line()
end

function set_description(t::ProgressBar, description::AbstractString)
  t.description = description
end

function set_postfix(t::ProgressBar; postfix...)
  t.postfix = values(postfix)
end

function set_multiline_postfix(t::ProgressBar, postfix::AbstractString)
  mistakenly_used_newline_at_start = postfix[1] == '\n' && length(postfix) > 1
  if mistakenly_used_newline_at_start
    postfix = postfix[2:end]
  end
  t.multilinepostfix = postfix
end

function postfix_repr(postfix::NamedTuple)::AbstractString
  return join(map(tpl -> ", $(tpl[1]): $(tpl[2])", zip(keys(postfix), postfix)))
end

make_space_after_progress_bar(extra_lines) = print("\n"^(extra_lines + 2))
erase_to_end_of_line() = print("\033[K")
move_up_1_line() = print("\033[1A")
move_down_1_line() = print("\033[1B")
go_to_start_of_line() = print("\r")
erase_line() = begin
  go_to_start_of_line()
  erase_to_end_of_line()
end


function newline_to_spaces(string, terminal_width)
  new_string = ""
  width_cumulator = 0
  for c in string
    if c == '\n'
      spaces_required = terminal_width - width_cumulator
      new_string *= " "^spaces_required
      width_cumulator = 0
    else
      new_string *= c
      width_cumulator += 1
    end
    if width_cumulator == terminal_width
      width_cumulator = 0
    end
  end
  return new_string
end


function Base.iterate(iter::ProgressBar)
  iter.start_time = time_ns() - iter.printing_delay
  iter.current = 0
  display_progress(iter)
  return iterate(iter.wrapped)
end

function Base.iterate(iter::ProgressBar,s)  
  iter.current += 1
  if(time_ns() - iter.last_print > iter.printing_delay)
    if !iter.fixwidth
      current_terminal_width = displaysize(stdout)[2]
      terminal_width_changed = current_terminal_width != iter.width
      if terminal_width_changed
        iter.width = current_terminal_width
        make_space_after_progress_bar(iter.extra_lines)
      end
    end
    display_progress(iter)
    iter.last_print = time_ns()
  end
  state = iterate(iter.wrapped,s)
  if state == nothing
    if iter.total > 0
      iter.current = iter.total
    end
    display_progress(iter)
    if !iter.leave
      clear_progress(iter)
    end
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
  if time_ns() - iter.last_print > iter.printing_delay
    display_progress(iter)
    iter.last_print = time_ns()
  elseif iter.current == iter.total
    # Reached end of iteration
    display_progress(itr)
    if !iter.leave
      clear_progress(iter)
    end
  end
  unlock(iter.mutex)
  return item
end

function Base.firstindex(iter::ProgressBar)
  lock(iter.mutex)
  iter.start_time = time_ns() - iter.printing_delay
  iter.current = 0
  display_progress(iter)
  unlock(iter.mutex)
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
  if time_ns() - iter.last_print > iter.printing_delay
    display_progress(iter)
    iter.last_print = time_ns()
  elseif iter.current == iter.total
    # Reached end of iteration
    display_progress(iter)
    if !iter.leave
      clear_progress(iter)
    end
  end
  unlock(iter.mutex)
  return item
end

function Base.println(t::ProgressBar, xs...)
  # Reset Cursor to beginning of the line
  for line in 1:t.extra_lines
    move_up_1_line()
    erase_line()
  end
  go_to_start_of_line()
  println(xs...)
  for line in 1:t.extra_lines
    move_down_1_line()
  end
  println()
  display_progress(t)
end

end # module
