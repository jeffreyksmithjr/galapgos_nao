defmodule GN.Orchestration do
  import GN.Gluon
  import GN.Evolution, only: [spawn_offspring: 1, build_layer: 2]
  alias GN.Network, as: Network
  import GN.Selection, only: [select: 1]

  # 5 minutes
  @timeout 300_000
  @max_parallel 4

  def pmap(collection, function) do
    collection
    |> Enum.map(&Task.async(fn -> function.(&1) end))
    |> Enum.map(&Task.await(&1, @timeout))
  end

  def start_and_spawn(seed_layers) do
    layers = spawn_offspring(seed_layers)

    {:ok, py} = start()
    built_layers = Enum.map(layers, &build_layer(&1, py))
    built_net = py |> call(build(built_layers))
    test_acc = py |> call(run(built_net))

    %Network{layers: layers, test_acc: test_acc}
  end

  def learn_generation(%Network{} = initial_net) do
    learn_generation(%{-1 => initial_net})
  end

  def learn_generation(nets) do
    batch_size = (@max_parallel / map_size(nets)) |> Statistics.Math.to_int()

    generation =
      for {_level, net} <- nets do
        seed_layers = net.layers
        pmap(1..batch_size, fn _n -> start_and_spawn(seed_layers) end)
      end
      |> Enum.flat_map(fn n -> n end)

    inspect_generation(generation)

    generation
  end

  def inspect_generation(nets) do
    for net <- nets do
      IO.puts(inspect(net))
    end
  end

  def evolve(net, generations) when generations > 0 do
    IO.puts("Generations remaining: #{generations}")

    learn_generation(net)
    |> select()
    |> evolve(generations - 1)
  end

  def evolve(net, _generations) do
    net
  end
end
