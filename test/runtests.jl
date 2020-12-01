using ProgressBars, Test, Printf

# Initialize bar to get default width
bar = ProgressBar(1:10)
pre = "Testing Progress Bars. All progress bars should end "
post = " here ▕"
num_dots = bar.width - length(pre) - length(post)
println(pre * repeat(".", num_dots) * post)

# Basic Test
for i in bar
end
@test true

# Length 1 iteration test
for i in ProgressBar(1:1)
end

# Test alias
for i in tqdm(1:1000)
  sleep(0.001)
end
@test true

# Test with description
iter = ProgressBar(1:1000)
for i in iter
  # ... Neural Network Training Code
  sleep(0.001)
  loss = exp(-i / 1000)
  set_description(iter, string(@sprintf("Loss: %.2f", loss)))
end
@test true
#
# Test with postfix
iter = ProgressBar(1:1000)
for i in iter
  sleep(0.001)
  loss = exp(-i / 1000)
  set_postfix(iter, Loss=@sprintf("%.2f", loss))
end
@test true

iter = ProgressBar(1:1000)
tic = time_ns()
for i in iter
  i = i * 2
end
toc = time_ns()
@test (toc - tic) / 1e9 < 1

for i in ProgressBar(1:100, total=-1)
  sleep(0.01)
end

# Test Threads for Julia 1.3
if VERSION >= v"1.3.0"
  a = []
  Threads.@threads for i in ProgressBar(1:1000)
    push!(a, i * 2)
  end
end
