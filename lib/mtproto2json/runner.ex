defmodule Mtproto2json.Runner do
  require Logger
  use GenServer

  alias Porcelain.Process, as: Proc

  @dir Application.get_env(:mtproto2json, :mtproto2json_dir)

  # interface
  def start_link(port) do
    Logger.info "#{__MODULE__} starting on port #{port}"
    GenServer.start_link(
      __MODULE__, [port], name: __MODULE__
    )
  end

  def proc(pid) do
    GenServer.call(pid, :proc)
  end

  # callbacks
  def init([port]) do
    Porcelain.spawn(
      Path.join(@dir, "streamjson.py"),
      ["--port", to_string port],
      dir: @dir,
      in: nil,
      out: nil,
      err: nil
    ) |> case do
           err = {:error, _} ->
             {:stop, err}

           proc = %Proc{} ->
             :timer.sleep(1000)
             :timer.send_interval(1000, self(), :alive?)
             {:ok, proc}
         end
  end

  def handle_info({pid, :data, :out, data}, proc=%{pid: proc_pid})
  when proc_pid == pid do
    Logger.debug "[out] #{data}"
    {:noreply, proc}
  end

  def handle_info({pid, :data, :err, data}, proc=%{pid: proc_pid})
  when proc_pid == pid do
    Logger.warn "[err] #{data}"
    {:noreply, proc}
  end

  def handle_info({pid, :result, %Porcelain.Result{status: status}}, %{pid: proc_pid})
  when proc_pid == pid do
    Logger.debug "[exit] status: #{status}"
    {:stop, :process_exited, nil}
  end

  def handle_info(:alive?, proc) do
    if Proc.alive?(proc) do
      {:noreply, proc}
    else
      Logger.warn "Process died"
      {:stop, :process_died, nil}
    end
  end

  def handle_info(info, proc) do
    Logger.warn "Unexpected info: #{inspect info}"
    {:noreply, proc}
  end

  def handle_call(:proc, _from, proc) do
    {:reply, proc, proc}
  end

  def terminate(_reason, nil), do: :ok
  def terminate(_reason, proc=%Proc{}) do
    Proc.stop(proc)
  end
end
