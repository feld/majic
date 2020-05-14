defmodule GenMagicTest do
  use GenMagic.MagicCase
  alias GenMagic.Result

  doctest GenMagic
  @iterations 100

  test "Makefile is text file" do
    {:ok, pid} = GenMagic.Server.start_link([])
    path = absolute_path("Makefile")
    assert {:ok, %{mime_type: "text/x-makefile"}} = GenMagic.Server.perform(pid, path)
  end

  @tag external: true
  test "Load test local files" do
    {:ok, pid} = GenMagic.Server.start_link([])

    files_stream()
    |> Stream.cycle()
    |> Stream.take(@iterations)
    |> Stream.map(&assert {:ok, %Result{}} = GenMagic.Server.perform(pid, &1))
    |> Enum.all?()
    |> assert
  end

  test "Non-existent file" do
    Process.flag(:trap_exit, true)
    {:ok, pid} = GenMagic.Server.start_link([])
    path = missing_filename()
    assert_no_file(GenMagic.Server.perform(pid, path))
  end

  test "Named process" do
    {:ok, pid} = GenMagic.Server.start_link(name: :gen_magic)
    path = absolute_path("Makefile")
    assert {:ok, %{cycles: 0}} = GenMagic.Server.status(:gen_magic)
    assert {:ok, %{cycles: 0}} = GenMagic.Server.status(pid)
    assert {:ok, %Result{} = result} = GenMagic.Server.perform(:gen_magic, path)
    assert {:ok, %{cycles: 1}} = GenMagic.Server.status(:gen_magic)
    assert {:ok, %{cycles: 1}} = GenMagic.Server.status(pid)
    assert "text/x-makefile" = result.mime_type
  end

  test "Custom database file recognises Elixir files" do
    database = absolute_path("test/elixir.mgc")
    IO.puts("Database: #{inspect(database)} #{inspect(File.exists?(database))}")
    {:ok, pid} = GenMagic.Server.start_link(database_patterns: [database])
    path = absolute_path("mix.exs")
    assert {:ok, %Result{} = result} = GenMagic.Server.perform(pid, path)
    assert "text/x-elixir" = result.mime_type
    assert "us-ascii" = result.encoding
    assert "Elixir module source text" = result.content
  end
end
