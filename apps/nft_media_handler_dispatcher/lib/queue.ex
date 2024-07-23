defmodule NFTMediaHandlerDispatcher.Queue do
  @moduledoc """
  Queue for fetching media
  """

  use GenServer

  alias Explorer.Chain.Token.Instance
  alias Explorer.Prometheus.Instrumenter

  def process_new_instance({:ok, %Instance{} = nft}) do
    url = get_media_url_from_metadata(nft.metadata)

    if url do
      GenServer.cast(__MODULE__, {:add_to_queue, {nft.token_contract_address_hash, nft.token_id, url}})
    else
      :ignore
    end
  end

  def process_new_instance(_), do: :ignore

  def add_media_to_fetch({_token_address_hash, _token_id, _media_url} = data_to_fetch) do
    GenServer.cast(__MODULE__, {:add_to_queue, data_to_fetch})
  end

  def get_urls_to_fetch(amount) do
    GenServer.call(__MODULE__, {:get_urls_to_fetch, amount})
  end

  def store_result({:down, _reason}, urls) do
    # somehow handle
    :ok
  end

  def store_result({result, media_type}, urls) do
    GenServer.cast(__MODULE__, {:finished, result, urls, media_type})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # todo: close dets if needed
  def init(_) do
    {:ok, queue} = :dets.open_file(:queue_storage, type: :bag)
    {:ok, in_progress} = :dets.open_file(:tasks_in_progress, type: :set)

    {:ok, {queue, in_progress, MapSet.new()}, {:continue, []}}
  end

  def handle_continue(_, {queue, in_progress, in_memory_queue}) do
    {:noreply, {queue, in_progress, fill_in_memory_queue(queue, in_memory_queue)}}
  end

  def handle_cast({:add_to_queue, {token_address_hash, token_id, media_url}}, {queue, in_progress, in_memory_queue}) do
    in_memory_queue =
      if MapSet.size(in_memory_queue) < in_memory_queue_limit() do
        MapSet.put(in_memory_queue, media_url)
      else
        in_memory_queue
      end

    :dets.insert(queue, {media_url, {token_address_hash, token_id}})

    {:noreply, {queue, in_progress, in_memory_queue}}
  end

  def handle_cast({:finished, result, url, media_type}, {queue, in_progress, _in_memory_queue} = state)
      when is_map(result) do
    now = System.monotonic_time()

    instances = :dets.lookup(queue, url)
    [{_, start_time}] = :dets.lookup(in_progress, url)

    :dets.delete(queue, url)
    :dets.delete(in_progress, url)

    Instrumenter.media_processing_time(System.convert_time_unit(now - start_time, :native, :millisecond) / 1000)

    Enum.map(instances, fn {_, instance_identifier} ->
      Instance.set_media_urls(instance_identifier, result, media_type)
    end)

    {:noreply, state}
  end

  def handle_call({:get_by_url, url}, _from, {queue, in_progress, in_memory_queue}) do
    {:reply, :dets.lookup(queue, url), {queue, in_progress, in_memory_queue}}
  end

  # todo:
  # - what if in_memory_queue less than amount
  # - to fill queue after getting urls
  # - mb go inplace to dets and take all the urls from it, and then from the list take some to return, others put to in_mem_que
  def handle_call({:get_urls_to_fetch, amount}, _from, {queue, in_progress, in_memory_queue}) do
    urls = in_memory_queue |> MapSet.to_list() |> Enum.take(amount)
    # DateTime.utc_now()
    now = System.monotonic_time()
    :dets.insert(in_progress, urls |> Enum.map(&{&1, now}))
    {:reply, urls, {queue, in_progress, MapSet.difference(in_memory_queue, MapSet.new(urls))}}
  end

  # todo: think about avoidance of fetching all the urls from DETS
  defp fill_in_memory_queue(queue_table, in_memory_queue) do
    to_collect = in_memory_queue_limit() - MapSet.size(in_memory_queue)

    if to_collect > 0 do
      urls =
        queue_table
        |> :dets.traverse(fn {url, {_token_address_hash, _token_id}} ->
          if MapSet.member?(in_memory_queue, url) do
            :continue
          else
            {:continue, url}
          end
        end)
        |> Enum.take(to_collect)

      MapSet.union(in_memory_queue, MapSet.new(urls))
    else
      in_memory_queue
    end
  end

  defp in_memory_queue_limit, do: Application.get_env(:nft_media_handler, :in_memory_queue_limit)

  def get_media_url_from_metadata(metadata) when is_map(metadata) do
    result =
      cond do
        metadata["image_url"] ->
          metadata["image_url"]

        metadata["image"] ->
          metadata["image"]

        is_binary(metadata["properties"]["image"]) ->
          metadata["properties"]["image"]

        metadata["animation_url"] ->
          retrieve_image(metadata["animation_url"])

        true ->
          nil
      end

    if result && String.trim(result) == "", do: nil, else: result
  end

  def get_media_url_from_metadata(nil, _), do: nil
end
