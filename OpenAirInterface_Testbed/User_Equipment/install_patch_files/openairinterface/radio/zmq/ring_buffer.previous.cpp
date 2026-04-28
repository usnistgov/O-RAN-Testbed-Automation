/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "ring_buffer.h"
#include <cstring>
#include <iostream>
#include <algorithm>

ring_buffer::ring_buffer(size_t max_size) : max_size_(max_size)
{
  buffer_ = std::make_unique<cf_t[]>(max_size);
}

size_t ring_buffer::push_samples(const cf_t *samples, const size_t nsamps)
{
  size_t overflow = 0;
  // if nsamps > max_size skip nsamps - max_size samples
  size_t nsamps_left = nsamps;
  if (nsamps > max_size_) {
    samples += nsamps - max_size_;
    nsamps_left = max_size_;
    overflow += nsamps - max_size_;
  }

  // Detect overflow
  if (size_ + nsamps_left > max_size_) {
    size_t newtail__pos = (head_ + nsamps_left) % max_size_;
    overflow += (size_ + nsamps_left) - max_size_;
    tail_ = newtail__pos;
  }

  size_t first_chunk = std::min(nsamps_left, max_size_ - head_);
  memcpy(&buffer_[head_], samples, first_chunk * sizeof(cf_t));
  head_ = (head_ + first_chunk) % max_size_;
  samples += first_chunk;
  nsamps_left -= first_chunk;
  if (nsamps_left > 0) {
    memcpy(&buffer_[0], samples, nsamps_left * sizeof(cf_t));
    head_ = nsamps_left;
  }

  size_ = std::min(size_ + nsamps, max_size_);

  return overflow;
}

size_t ring_buffer::push_zeros(const size_t num_zeros)
{
  size_t overflow = 0;
  // if nsamps > max_size skip nsamps - max_size samples
  size_t nsamps_left = num_zeros;
  if (num_zeros > max_size_) {
    nsamps_left = max_size_;
    overflow += num_zeros - max_size_;
  }

  // Detect overflow
  if (size_ + nsamps_left > max_size_) {
    size_t new_tail_pos = (head_ + nsamps_left) % max_size_;
    overflow += (size_ + nsamps_left) - max_size_;
    tail_ = new_tail_pos;
  }

  size_t first_chunk = std::min(nsamps_left, max_size_ - head_);
  memset(&buffer_[head_], 0, first_chunk * sizeof(cf_t));
  head_ = (head_ + first_chunk) % max_size_;
  nsamps_left -= first_chunk;
  if (nsamps_left > 0) {
    memset(&buffer_[0], 0, nsamps_left * sizeof(cf_t));
    head_ = nsamps_left;
  }

  size_ = std::min(size_ + num_zeros, max_size_);

  return overflow;
}

size_t ring_buffer::pop_samples(cf_t *samples, size_t num_samples)
{
  size_t samples_to_pop = std::min(size_, num_samples);
  if (samples_to_pop > 0) {
    if (tail_ + samples_to_pop > max_size_) {
      size_t first_chunk = max_size_ - tail_;
      memcpy(samples, &buffer_[tail_], first_chunk * sizeof(cf_t));
      memcpy(samples + first_chunk, &buffer_[0], (samples_to_pop - first_chunk) * sizeof(cf_t));
    } else {
      memcpy(samples, &buffer_[tail_], samples_to_pop * sizeof(cf_t));
    }
    tail_ = (tail_ + samples_to_pop) % max_size_;
    size_ -= samples_to_pop;
    return samples_to_pop;
  }
  return 0;
}

void ring_buffer::clear_samples()
{
  head_ = 0;
  tail_ = 0;
  size_ = 0;
}

void ring_buffer::reset()
{
  clear_samples();
}

size_t ring_buffer::size() const
{
  return size_;
}

size_t overflow_buffer::push_samples(const cf_t *samples, size_t nsamps)
{
  std::lock_guard<std::mutex> lock(mutex_);
  size_t overflow = buffer_.push_samples(samples, nsamps);
  zeros_to_send_ += overflow;
  return overflow;
}

size_t overflow_buffer::push_zeros(size_t num_zeros)
{
  std::lock_guard<std::mutex> lock(mutex_);
  size_t overflow = buffer_.push_zeros(num_zeros);
  zeros_to_send_ += overflow;
  return overflow;
}

size_t overflow_buffer::pop_samples(cf_t *samples, size_t num_samples)
{
  std::lock_guard<std::mutex> lock(mutex_);
  size_t samples_popped = 0;
  if (zeros_to_send_ > 0) {
    size_t num_zeros = std::min(zeros_to_send_, num_samples);
    memset(samples, 0, num_zeros * sizeof(cf_t));
    zeros_to_send_ -= num_zeros;
    samples += num_zeros;
    num_samples -= num_zeros;
    samples_popped += num_zeros;
  }

  if (num_samples > 0) {
    samples_popped += buffer_.pop_samples(samples, num_samples);
  }
  return samples_popped;
}

void overflow_buffer::reset()
{
  std::lock_guard<std::mutex> lock(mutex_);
  buffer_.reset();
  zeros_to_send_ = buffer_.size() / 2;
}

void overflow_buffer::clear_samples()
{
  std::lock_guard<std::mutex> lock(mutex_);
  buffer_.clear_samples();
  zeros_to_send_ = 0;
}

size_t overflow_buffer::size()
{
  std::lock_guard<std::mutex> lock(mutex_);
  return buffer_.size() + zeros_to_send_;
}
