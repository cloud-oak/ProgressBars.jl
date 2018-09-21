"""
Customisable progressbar decorator for iterators.
Usage:
  > using Tqdm
  > for i in tqdm(1:10)
  > ....
  > end
"""
module Tqdm

using Dates, Printf

EIGHTS = Dict(0 => ' ',
			  1 => '▏',
			  2 => '▎',
			  3 => '▍',
			  4 => '▌',
			  5 => '▋',
			  6 => '▊',
			  7 => '▉',
			  8 => '█')

export tqdm
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
    start_time::DateTime

    function tqdm(wrapped::Any; total::Int = -1, width = 80)
        this = new()
        this.wrapped = wrapped
        this.width = width
        this.start_time = now()
        this.total = length(wrapped)
        return this
    end
end

function format(seconds)
    mins, s = divrem(round(seconds), 60)
    h, m    = divrem(mins, 60)
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
            seconds   = (now() - t.start_time).value / 1000
            speed     = iteration / seconds
            ETA       = t.total / iteration * seconds
        else
            ETA = Inf; speed = 0.0; seconds = Inf
        end

        percentage_string = string(@sprintf("%.2f%%",t.current/t.total*100))
    end

    width = t.width - length(percentage_string) - 2
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
    status_string = string(t.current,"/",t.total,
                            " [", format(seconds), "<", format(ETA),
                            " , ", @sprintf("%.2f it/s", speed),"]")
    print(status_string)

end

function Base.iterate(iter::tqdm)
    iter.start_time = now()
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
