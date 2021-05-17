using ProgressBars, Test, Printf

# Initialize bar to get default width
bar = ProgressBar(1:10)
pre = "Testing Progress Bars. All progress bars should end "
post = " here ▕"
num_dots = bar.width - length(pre) - length(post)
println(pre * repeat(".", num_dots) * post)

println("> Basic pbar test")
for i in bar
end
@test true

println("> Test time taken for a fast iteration (printing only every 50ms)")
iter = ProgressBar(1:10000, printing_delay=0.05)
tic = time_ns()
for i in iter
  i = i * 2
end
toc = time_ns()
@test (toc - tic) / 1e9 < 0.2
println("> Took $((toc - tic) * 1e-6)ms")

println("> Test time taken when printing every iteration, should be much longer than previous one")
iter = ProgressBar(1:10000, printing_delay=0)
tic = time_ns()
for i in iter
  i = i * 2
end
toc = time_ns()
@test true
println("> Took $((toc - tic) * 1e-6)ms")

println("> Test special case of single iteration progress bar")
for i in ProgressBar(1:1)
end

println("> Test tqdm alias")
for i in tqdm(1:1000)
  sleep(0.0001)
end
@test true

println("> Test print from within a ProgressBar Loop")
iter = ProgressBar(1:5)
for i in iter
  println(iter, "Printing from iteration $i")
  sleep(0.2)
end

println("> Test with description")
iter = ProgressBar(1:1000)
for i in iter
  # ... Neural Network Training Code
  sleep(0.0001)
  loss = exp(-i / 1000)
  set_description(iter, string(@sprintf("Loss: %.2f", loss)))
end
@test true

println("> Test with regular postfix")
iter = ProgressBar(1:1000)
for i in iter
  sleep(0.0001)
  loss = exp(-i / 1000)
  set_postfix(iter, Loss=@sprintf("%.2f", loss))
end
@test true

println("> Test with multiline postfix")
iter = ProgressBar(1:1000)
for i in iter
  sleep(0.0001)
  loss = exp(-i / 1000)
  set_multiline_postfix(iter, "Test 1: $(rand())\nTest 2: $(rand())\nTest 3: $loss")
end
@test true

println("> Test with regular postfix and multiline postfix")
iter = ProgressBar(1:1000)
for i in iter
  sleep(0.0001)
  loss = exp(-i / 1000)
  set_postfix(iter, Loss=@sprintf("%.2f", loss))
  set_multiline_postfix(iter, "Test 1: $(rand())\nTest 2: $(rand())\nTest 3: $loss")
end
@test true

println("> Test with leave=false, there should be no pbar left below this!")
iter = ProgressBar(1:1000, leave=false)
for i in iter
  sleep(0.0001)
end
@test true

println("> Testing pbar without total number specified")
for i in ProgressBar(1:100, total=-1)
  sleep(0.001)
end
@test true

println("> Testing Threads for Julia 1.3")
if VERSION >= v"1.3.0"
  a = []
  Threads.@threads for i in ProgressBar(1:1000)
    push!(a, i * 2)
  end
end
@test true

println("> Testing pbar with custom units")
for i in ProgressBar(1:100, unit="flobberwobbles")
  sleep(0.001)
end
@test true
