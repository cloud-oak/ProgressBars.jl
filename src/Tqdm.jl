"""
Customisable progressbar decorator for iterators.
Usage:
  > using Tqdm
  > for i in tqdm(1:10)
  > ....
  > end
"""
module Tqdm

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

export tqdm, set_description
"""
Decorate an iterable object, returning an iterator which acts exactly
like the original iterable, but prints a dynamically updating
progressbar every time a value is requested.
"""
mutable struct tqdm
    wrapped::Any
    total::Int
    current::Int
    width::Int
    start_time::UInt
    description::AbstractString

    function tqdm(wrapped::Any; total::Int = -1, width = 100)
        this = new()
        this.wrapped = wrapped
        this.width = width
        this.start_time = time_ns()
        this.total = length(wrapped)
        this.description = ""
        return this
    end
end

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

function display_progress(t::tqdm)
    print(repeat("\r", t.width))
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

function set_description(t::tqdm, description::AbstractString)
  t.description = description
end

function Base.iterate(iter::tqdm)
    iter.start_time = time_ns()
    iter.current = -1
    return iterate(iter.wrapped)
end


function Base.iterate(iter::tqdm,s)
    iter.current += 1
    display_progress(iter)
    state = iterate(iter.wrapped,s)
    if state===nothing
        iter.current = iter.total
        display_progress(iter)
        return nothing
    end
    return state
end
Base.length(iter::tqdm) = length(iter.wrapped)
Base.eltype(iter::tqdm) = eltype(iter.wrapped)

end # module
