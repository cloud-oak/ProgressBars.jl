using ProgressBars, Test, Printf

# Basic Test
for i in ProgressBar(1:10)
end
@test true

# Test alias
for i in tqdm(1:10)
end
@test true

# Test with description
iter = ProgressBar(1:100)
for i in iter
  # ... Neural Network Training Code
  loss = exp(-i)
  set_description(iter, string(@sprintf("Loss: %.2f", loss)))
end
@test true

iter = ProgressBar(1:100000)
tic = time_ns()
for i in iter
  i = i * 2
end
toc = time_ns()
@test (toc - tic) / 1e9 < 1
