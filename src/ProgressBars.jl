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

export ProgressBar, tqdm, set_description, set_postfix, set_multiline_postfix, update
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
  cleared::Bool
  start_time::UInt64
  last_print::UInt64
  postfix::NamedTuple
  extra_lines::Int
  printing_delay::UInt64
  unit::AbstractString
  iter_unit::AbstractString
  unit_scale::Bool
  description::AbstractString
  multilinepostfix::AbstractString
  mutex::Threads.SpinLock
  output_stream::IO

  function ProgressBar(wrapped::Any=nothing;
                       total::Int=-2,
                       width::Union{UInt, Nothing}=nothing,
                       leave::Bool=true,
                       unit::AbstractString="",
                       unit_scale::Bool=true,
                       printing_delay::Number=0.05,
                       output_stream::IO=stderr)
    this = new()
    this.wrapped = wrapped
    if width == nothing
        this.width = displaysize(output_stream)[2]
        this.fixwidth = false
    else
        this.width = width
        this.fixwidth = true
    end
    this.leave = leave
    this.cleared = false
    this.printing_delay = trunc(UInt64, printing_delay * 1e9)
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
    this.output_stream = output_stream

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

function display_progress(t::ProgressBar; force::Bool=false)
  if t.current == t.total
    if t.leave
      force = true
    else
      clear_progress(t)
      return
    end
  end

  if !force && (time_ns() - t.last_print < t.printing_delay)
    return
  end

  if !t.fixwidth
    current_terminal_width = displaysize(t.output_stream)[2]
    terminal_width_changed = current_terminal_width != t.width
    if terminal_width_changed
      t.width = current_terminal_width
      make_space_after_progress_bar(t.output_stream, t.extra_lines)
    end
  end

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
    move_up_1_line(t.output_stream)
  end
  go_to_start_of_line(t.output_stream)

  if t.description != ""
    barwidth -= length(t.description) + 1
    print(t.output_stream, t.description * " ")
  end

  if (t.total <= 0)
    current = format_amount(t.current, t.iter_unit, t.unit_scale)
    status_string = "$(current) $elapsed [$iterations_per_second$postfix_string]"
    barwidth -= length(status_string) + 1
    if barwidth < 0
      barwidth = 0
    end

    print(t.output_stream, "┣")
    print(t.output_stream, join(IDLE[1 + ((i + t.current) % length(IDLE))] for i in 1:barwidth))
    print(t.output_stream, "┫ ")
    print(t.output_stream, status_string)
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

    print(t.output_stream, percentage_string)
    print(t.output_stream, "┣")
    print(t.output_stream, repeat("█", Int(full_cells)))
    if (full_cells < barwidth)
      part = Int(floor(9 * remain / cellvalue))
      print(t.output_stream, EIGHTS[part])
      print(t.output_stream, repeat(" ", Int(barwidth - full_cells - 1)))
    end

    print(t.output_stream, "┫ ")
    print(t.output_stream, status_string)
  end
  multiline_postfix_string = newline_to_spaces(t.multilinepostfix, t.width)
  t.extra_lines = ceil(Int, length(multiline_postfix_string) / t.width) + 1
  print(t.output_stream, multiline_postfix_string)
  println(t.output_stream)

  t.last_print = time_ns()
end

function clear_progress(t::ProgressBar)
  # Reset cursor, fill width with empty spaces, and then reset again
  if t.cleared
    # Only clear once
    return
  end
  erase_line(t.output_stream)
  for line in 1:(t.extra_lines)
    erase_line(t.output_stream)
    move_up_1_line(t.output_stream)
  end
  erase_line(t.output_stream)
  t.cleared = true
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

make_space_after_progress_bar(output_stream::IO, extra_lines) = print(output_stream, "\n"^(extra_lines + 2))
erase_to_end_of_line(output_stream::IO) = print(output_stream, "\033[K")
move_up_1_line(output_stream::IO) = print(output_stream, "\033[1A")
move_down_1_line(output_stream::IO) = print(output_stream, "\033[1B")
go_to_start_of_line(output_stream::IO) = print(output_stream, "\r")
erase_line(output_stream::IO) = begin
  go_to_start_of_line(output_stream)
  erase_to_end_of_line(output_stream)
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

function update(iter::ProgressBar, amount::Int=1)
  iter.current += amount
  display_progress(iter)
end

function Base.iterate(iter::ProgressBar)
  iter.start_time = time_ns() - iter.printing_delay
  iter.current = 0
  display_progress(iter, force=true)
  return iterate(iter.wrapped)
end

function Base.iterate(iter::ProgressBar,s)  
  update(iter, 1)

  state = iterate(iter.wrapped,s)
  if state == nothing
    if iter.total > 0
      iter.current = iter.total
    end
    display_progress(iter, force=true)
    return nothing
  end
  return state
end

function Base.length(iter::ProgressBar)
  if iter.total > 0
    return iter.total
  else
    return length(iter.wrapped)
  end
end

Base.eltype(iter::ProgressBar) = eltype(iter.wrapped)

function Base.unsafe_getindex(iter::ProgressBar, index::Int64)
  """
  Base.unsafe_getindex is used by the `Threads.@threads for ... in ...` macro
  in julia 1.3.
  This wrapper will do weird things when used directly.
  """
  item = Base.unsafe_getindex(iter.wrapped, index)
  lock(iter.mutex)
  update(iter)

  display_progress(iter)
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
  display_progress(iter)
  unlock(iter.mutex)
  return item
end

function Base.println(t::ProgressBar, xs...)
  # Reset Cursor to beginning of the line
  for line in 1:t.extra_lines
    move_up_1_line(t.output_stream)
    erase_line(t.output_stream)
  end
  go_to_start_of_line(t.output_stream)
  println(xs...) # goes to stdout, by default
  println(t.output_stream)
  display_progress(t) # goes to stdout, by default
end

end # module
