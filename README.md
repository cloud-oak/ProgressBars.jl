# ProgressBars.jl (formerly Tqdm.jl)
A fast, extensible progress bar for Julia. This is a Julia clone of the great Python package  [`tqdm`](https://pypi.python.org/pypi/tqdm).

## Installation 

Run the following in a julia prompt:

```julia
using Pkg
Pkg.add("ProgressBars")
```

## Usage
```julia
julia> using ProgressBars

julia> for i in ProgressBar(1:100000) #wrap any iterator
          #code
       end
100.00%┣█████████████████████████████████████████████████┫ 100000/100000 [00:12<00:00 , 8616.43 it/s]
```
There is a `tqdm` alias, so that people coming from python will feel right at home :)

```julia
julia> using ProgressBars

julia> for i in tqdm(1:100000) #wrap any iterator
          #code
       end
100.00%┣█████████████████████████████████████████████████┫ 100000/100000 [00:12<00:00 , 8616.43 it/s]
```

Iterating with a custom unit (e.g. bytes)
```julia
julia> iter = ProgressBar(1:2_000_000, unit="B", unit_scale=true)
       for i in iter
           # Do stuff
       end
100.0%┣██████████████████████████████████████████████████████████┫ 2.0MB/2.0MB [00:00<00:00, 4.8MB/s]
```


Or with a set description (e.g. for loss values when training neural networks)
```julia
julia> iter = ProgressBar(1:100)
       for i in iter
          # ... Neural Network Training Code
          loss = exp(-i)
          set_description(iter, string(@sprintf("Loss: %.2f", loss)))
       end
Loss: 0.02 3.00%┣█▌                                                  ┫ 3/100 00:00<00:02, 64.27 it/s]
```

Printing persistent messages while using a ProgressBar:
```julia
julia> iter = ProgressBar(1:5)
       for i in iter
         println(iter, "Printing from iteration $i")
         sleep(0.2)
       end
Printing from iteration 1
Printing from iteration 2
Printing from iteration 3
Printing from iteration 4
Printing from iteration 5
100.0%┣█████████████████████████████████████████████████████████████████┫ 5/5 [00:03<00:00, 1.5 it/s]
```

Postfixes are also possible, if that's your kind of thing:
```julia
julia> iter = ProgressBar(1:100)
       for i in iter
          # ... Neural Network Training Code
          loss = exp(-i)
          set_postfix(iter, Loss=@sprintf("%.2f", loss))
       end
100.0%┣█████████████████████████████████████████████┫ 1000/1000 [00:02<00:00, 420.4 it/s, Loss: 0.37]
```
You can also use multi-line postfixes, like so:
```julia
julia> iter = ProgressBar(1:100)
       for i in iter
          # ... Neural Network Training Code
          loss = exp(-i)
          set_multiline_postfix(iter, "Test 1: $(rand())\nTest 2: $(rand())\nTest 3: $loss)")
       end
100.0%┣█████████████████████████████████████████████████████████┫ 1000/1000 [00:02<00:00, 420.4 it/s]
Test1: 0.6740503146383823
Test2: 0.23694728303439727
Test3: 0.06787944117144233
```

### Parallel for-loops

Now with added support for `Threads.@threads for`:

```julia
julia> a = []
       Threads.@threads for i in ProgressBar(1:1000)
         push!(a, i * 2)
       end
100.00%┣██████████████████████████████████████████████████████┫ 1000/1000 00:00<00:00, 28753.50 it/s]
```


### Printing Delay

By default, the progress bar will update at most every 50ms in order to prevent the string IO from slowing down very fast iterations.
This can be adjusted by passing the desired printing delay (in seconds) to the `printing_delay`-parameter when constructing the progress bar:

```julia
julia> for i in ProgressBar(1:1000, printing_delay=0.001)
         # do stuff
       end
100.0%┣████████████████████████████████████████████████████████┫ 1000/1000 [00:00<00:00, 3006.8 it/s]
```
