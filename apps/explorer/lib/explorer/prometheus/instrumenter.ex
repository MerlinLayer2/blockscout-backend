defmodule Explorer.Prometheus.Instrumenter do
  @moduledoc """
  Blocks fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @histogram [
    name: :block_import_stage_runner_duration_microseconds,
    labels: [:stage, :runner, :step],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block import stage, runner and step in runner processing time"
  ]

  @histogram [
    name: :media_processing_time,
    buckets: :default,
    duration_unit: :seconds,
    help: "Time in seconds taken for media resizing and uploading"
  ]

  @gauge [
    name: :weekly_success_transactions_number,
    help: "Number of successful transactions in the last 7 days",
    registry: :public
  ]

  @gauge [
    name: :weekly_deployed_smart_contracts_number,
    help: "Number of deployed smart-contracts in the last 7 days",
    registry: :public
  ]

  @gauge [
    name: :weekly_verified_smart_contracts_number,
    help: "Number of verified smart-contracts in the last 7 days",
    registry: :public
  ]

  @gauge [
    name: :weekly_new_addresses_number,
    help: "Number of new wallet addresses in the last 7 days",
    registry: :public
  ]

  @gauge [
    name: :weekly_new_tokens_number,
    help: "Number of new tokens detected in the last 7 days",
    registry: :public
  ]

  @gauge [
    name: :weekly_new_token_transfers_number,
    help: "Number of new token transfers detected in the last 7 days",
    registry: :public
  ]

  @gauge [
    name: :weekly_active_addresses_number,
    help: "Number of active EOA addresses (participated in transactions in to/from) in the last 7 days",
    registry: :public
  ]

  @counter [
    name: :successfully_uploaded_media_number,
    help: "Number of successfully uploaded media to CDN",
    registry: :public
  ]

  @counter [
    name: :failed_uploading_media_number,
    help: "Number of failed uploading to CDN media",
    registry: :public
  ]

  def block_import_stage_runner(function, stage, runner, step) do
    {time, result} = :timer.tc(function)

    Histogram.observe([name: :block_import_stage_runner_duration_microseconds, labels: [stage, runner, step]], time)

    result
  end

  def media_processing_time(seconds) do
    dbg(seconds)
    Histogram.observe([name: :media_processing_time], seconds)
  end

  def weekly_success_transactions_number(number) do
    Gauge.set([name: :weekly_success_transactions_number, registry: :public], number)
  end

  def weekly_deployed_smart_contracts_number(number) do
    Gauge.set([name: :weekly_deployed_smart_contracts_number, registry: :public], number)
  end

  def weekly_verified_smart_contracts_number(number) do
    Gauge.set([name: :weekly_verified_smart_contracts_number, registry: :public], number)
  end

  def weekly_new_addresses_number(number) do
    Gauge.set([name: :weekly_new_addresses_number, registry: :public], number)
  end

  def weekly_new_tokens_number(number) do
    Gauge.set([name: :weekly_new_tokens_number, registry: :public], number)
  end

  def weekly_new_token_transfers_number(number) do
    Gauge.set([name: :weekly_new_token_transfers_number, registry: :public], number)
  end

  def weekly_simplified_active_addresses_number(number) do
    Gauge.set([name: :weekly_active_addresses_number, registry: :public], number)
  end

  def increment_successfully_uploaded_media_number do
    Counter.inc(name: :successfully_uploaded_media_number, registry: :public)
  end

  def increment_failed_uploading_media_number do
    Counter.inc(name: :failed_uploading_media_number, registry: :public)
  end
end
