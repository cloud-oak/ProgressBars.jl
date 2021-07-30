using ProgressBars, Test
using BenchmarkTools

counter = 0
function iterate(delay::Float64)
    global counter = 0
    for i in ProgressBar(1:1000000, printing_delay=delay, leave=false)
        global counter += i
    end
end

function standard()
    global counter = 0
    for i in 1:1000000
        global counter += 1
    end
end

println(stderr, "Benchmarking ProgressBar with 1M iters and printing_delay=0.2")
results = @benchmark iterate(0.2)
display(results)
@test true

println(stderr, "\nBenchmarking ProgressBar with 1M iters and printing_delay=0.1")
results = @benchmark iterate(0.2)
display(results)
@test true

println(stderr, "\nBenchmarking ProgressBar with 1M iters and printing_delay=0.05")
results = @benchmark iterate(0.05)
display(results)
@test true

println(stderr, "\nStandard 1M iterator in Julia")
results = @benchmark standard()
display(results)
@test true
