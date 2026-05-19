/*
 * SPDX-License-Identifier: BSD-3-Clause-Open-MPI
 * Based on zmq library in OCUDU project: ocudu/lib/radio/zmq
 * Refer to https://gitlab.com/ocudu/ocudu/-/raw/dev/LICENSE?ref_type=heads
 */

#include "zmq_imported.h"
#include "log.h"

const float c16_t_to_cf_t_factor = std::numeric_limits<int16_t>::max();
static constexpr std::chrono::milliseconds TRANSMIT_TS_ALIGN_TIMEOUT = std::chrono::milliseconds(0);
static constexpr std::chrono::milliseconds RECEIVE_TS_ALIGN_TIMEOUT = std::chrono::milliseconds(100);

void zmq_tx_channel::transmit(c16_t *samples, size_t nsamps, uint64_t timestamp)
{
  std::scoped_lock lock(transmit_alignment_mutex_);
  size_t overflow = 0;
  if (timestamp > sample_count_) {
    overflow += buffer_.push_zeros(timestamp - sample_count_);
    sample_count_ = timestamp;
  }
  cf_t samples_float[nsamps];
  for (size_t i = 0; i < nsamps; i++) {
    samples_float[i].r = samples[i].r / c16_t_to_cf_t_factor;
    samples_float[i].i = samples[i].i / c16_t_to_cf_t_factor;
  }
  overflow += buffer_.push_samples(samples_float, nsamps);
  sample_count_ += nsamps;
  if (overflow) {
    LOG_W(HW, "Overflow on ZMQ channel by %lu samples\n", overflow);
  }
  is_tx_enabled_ = true;
  transmit_alignment_cvar_.notify_all();
}

void zmq_tx_channel::start(uint64_t init_time)
{
  sample_count_ = init_time;
}

bool zmq_tx_channel::align(uint64_t timestamp, std::chrono::milliseconds timeout)
{
  if (sample_count_ >= timestamp) {
    return sample_count_ > timestamp;
  }
  std::unique_lock<std::mutex> lock(transmit_alignment_mutex_);
  if (is_tx_enabled_ && (timeout.count() != 0)) {
    bool is_not_timeout =
        transmit_alignment_cvar_.wait_for(lock, timeout, [this, timestamp]() { return sample_count_ >= timestamp; });
    if (is_not_timeout) {
      return sample_count_ > timestamp;
    }
    LOG_W(HW, "Timeout waiting for TX path to align samples\n");
    is_tx_enabled_ = false;
  }
  if (sample_count_ < timestamp) {
    buffer_.push_zeros(timestamp - sample_count_);
    sample_count_ = timestamp;
  }
  return false;
}

void zmq_rx_channel::receive(c16_t *samples, size_t nsamps)
{
  size_t samples_popped = 0;
  cf_t samples_float[nsamps];
  while (samples_popped < (size_t)nsamps && !stopped_) {
    size_t popped_now = buffer_.pop_samples(samples_float + samples_popped, nsamps - samples_popped);
    samples_popped += popped_now;
    if (popped_now == 0) {
      usleep(100); // wait for more samples to arrive
    }
  }
  for (size_t i = 0; i < nsamps; i++) {
    samples[i].r = samples_float[i].r * c16_t_to_cf_t_factor + 0.5;
    samples[i].i = samples_float[i].i * c16_t_to_cf_t_factor + 0.5;
  }
}
void zmq_rx_channel::stop()
{
  stopped_ = true;
}

void zmq_tx_stream::start(uint64_t init_time)
{
  for (auto &chan : channels_) {
    chan->start(init_time);
  }
}
bool zmq_tx_stream::align(uint64_t timestamp, std::chrono::milliseconds timeout)
{
  bool timestamp_passed = false;
  for (auto &chan : channels_) {
    timestamp_passed = timestamp_passed || chan->align(timestamp, timeout);
  }
  return timestamp_passed;
}
void zmq_tx_stream::transmit(c16_t **samples, size_t nsamps, uint64_t timestamp)
{
  bool timestamp_passed = align(timestamp, TRANSMIT_TS_ALIGN_TIMEOUT);
  if (timestamp_passed) {
    LOG_W(HW, "Error, channel timeout\n");
    return;
  }
  int i = 0;
  for (auto chan : channels_) {
    chan->transmit(samples[i++], nsamps, timestamp);
  }
}

void zmq_rx_stream::start(uint64_t init_time)
{
  sample_count_ = init_time;
}
void zmq_rx_stream::stop()
{
  for (auto &chan : channels_) {
    chan->stop();
  }
}
void zmq_rx_stream::receive(c16_t **samples, size_t nsamps, uint64_t *timestamp)
{
  *timestamp = sample_count_;
  uint64_t passed_timestamp = sample_count_ + nsamps;
  tx_stream_->align(passed_timestamp, RECEIVE_TS_ALIGN_TIMEOUT);
  int i = 0;
  for (auto chan : channels_) {
    chan->receive(samples[i++], nsamps);
  }
  sample_count_ += nsamps;
}
