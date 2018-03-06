defmodule CertifcateBufferTest do
  use ExUnit.Case

  test "ETS table is created and destroyed properly" do
    {:ok, buffer_pid} = Certstream.CertifcateBuffer.start_link([])
    Process.unlink(buffer_pid)

    ref = Process.monitor(buffer_pid)

    # Assert ets table creation
    assert :ets.info(:counter) != :undefined

    # Kill process
    Process.exit(buffer_pid, :kill)

    # Wait for the process to die
    receive do
      {:DOWN, ^ref, _, _, _} ->
        # Ensure ets table is cleaned up properly upon agent termination
        assert :ets.info(:counter) == :undefined
    end

    # Start agent again
    {:ok, buffer_pid} = Certstream.CertifcateBuffer.start_link([])
    Process.unlink(buffer_pid)

    # Assert it re-created the table
    assert :ets.info(:counter) != :undefined
  end
end