using Tqdm,Test,Printf
# write your own tests here

for i in tqdm([1,2,3,4])
end

iter = tqdm(1:100)
for i in iter
  # ... Neural Network Training Code
  loss = exp(-i)
  set_description(iter, string(@sprintf("Loss: %.2f", loss)))
end
@test true
