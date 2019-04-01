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
100.00%┣████████████████████████████████████████████████▉┫ 100000/100000 [00:12<00:00 , 8616.43 it/s]
```
There is a `tqdm` alias, so that people coming from python will feel right at home :)

```julia
julia> using ProgressBars

julia> for i in tqdm(1:100000) #wrap any iterator
          #code
       end
100.00%┣████████████████████████████████████████████████▉┫ 100000/100000 [00:12<00:00 , 8616.43 it/s]
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


