__precompile__()
"""
Customisable progressbar decorator for iterators.
Usage:
  > using Tqdm
  > for i in tqdm(1:10)
  > ....
  > end
"""
module Tqdm

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
type tqdm
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

        iteratorSize = Base.iteratorsize(wrapped)
        if (iteratorSize == Base.HasShape()) || (iteratorSize == Base.HasLength())
            this.total = length(wrapped)
        elseif (iteratorSize == Base.IsInfinite())
            this.total = -1
        else
            this.total = total
        end

        return this
    end
end

function display_progress(t::tqdm)
    print(repeat("\r", t.width))
    if (t.total <= 0)
        status_string = string(t.current)
    else
        if (t.current > 0)
            td = (now() - t.start_time).value
            ratio = (t.total / t.current - 1)
            ETA = td * ratio / 1000
            unit = "s"
            if (ETA > 60)
                ETA /= 60
                unit = "m"
            end
            if (ETA > 60)
                ETA /= 60
                unit = "h"
            end
            ETA = Int(floor(ETA))
            if ETA < 10
                ETA = string(" ", ETA)
            else
                ETA = string(ETA)
            end
        else
            ETA = "???"
            unit = ""
        end

        status_string = string(t.current, "/", t.total, " ETA:", ETA, unit)
    end

    width = t.width - length(status_string) - 2
    print(status_string)
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
    print("┫")
end

function Base.start(t::tqdm)
    t.current = -1
    t.start_time = now()
    return Base.start(t.wrapped)
end

function Base.next(t::tqdm, state)
    t.current += 1
    display_progress(t)
    return Base.next(t.wrapped, state)
end

function Base.done(t::tqdm, state)
	isDone = Base.done(t.wrapped, state)
	if isDone
		t.current = t.total
		display_progress(t)
	end
    return isDone
end

end # module
