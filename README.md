# Tqdm
A fast, extensible progress bar for Julia. This is a Julia clone of the great Python package  [`tqdm`](https://pypi.python.org/pypi/tqdm).

## Usage
```julia
julia> using Tqdm

julia> for i in tqdm(1:100000) #wrap any iterator
          #code
       end
100.00%┣████████████████████████████████████████████████▉┫ 100000/100000 [00:12<00:00 , 8616.43 it/s]
```
