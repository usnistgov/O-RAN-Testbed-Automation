// SPDX-FileCopyrightText: Copyright (C) 2021-2026 Software Radio Systems Limited
// SPDX-License-Identifier: BSD-3-Clause-Open-MPI

#pragma once

#include "radio_zmq_rx_channel_fsm.h"
#include "ocudu/adt/blocking_queue.h"
#include "ocudu/adt/complex.h"
#include "ocudu/ocudulog/ocudulog.h"
#include "ocudu/radio/radio_event_notifier.h"
#include "ocudu/support/executors/task_executor.h"
#include "ocudu/support/synchronization/stop_event.h"
#include <zmq.h>

namespace ocudu {

/// Radio receive channel over ZeroMQ socket.
class radio_zmq_rx_channel
{
  /// Indicates the stream identifier. Used for notifying events.
  unsigned stream_id;
  /// Channel identifier. Used for notifying events.
  unsigned channel_id;
  /// Indicates the current state of the stream.
  radio_zmq_rx_channel_fsm state_fsm;
  /// Stop control.
  rt_stop_event_source stop_control;
  /// ZMQ socket.
  void* sock = nullptr;
  /// ZMQ socket type.
  int socket_type;
  /// Logger.
  ocudulog::basic_logger& logger;
  /// Stores transmit buffer.
  blocking_queue<cf_t> circular_buffer;
  /// Transmission buffer.
  std::vector<cf_t> buffer;
  /// Notification handler.
  radio_event_notifier& notification_handler;
  /// Asynchronous task executor.
  task_executor& async_executor;

public:
  /// Describes the necessary parameters to create a ZMQ Tx channel.
  struct channel_description {
    /// Indicates the socket type.
    int socket_type;
    /// Indicates the address to bind.
    std::string address;
    /// Stream identifier.
    unsigned stream_id;
    /// Channel identifier.
    unsigned channel_id;
    /// Stream identifier string.
    std::string channel_id_str;
    /// Logging level.
    ocudulog::basic_levels log_level;
    /// Indicates the socket send and receive timeout in milliseconds. It is ignored if it is zero.
    unsigned trx_timeout_ms;
    /// Indicates the socket linger timeout in milliseconds. If is ignored if trx_timeout_ms is zero.
    unsigned linger_timeout_ms;
    /// Buffer size.
    unsigned buffer_size;
  };

  radio_zmq_rx_channel(void*                      zmq_context,
                       const channel_description& config,
                       radio_event_notifier&      notification_handler,
                       task_executor&             async_executor_);

  ~radio_zmq_rx_channel();

  bool is_successful() const { return state_fsm.is_running(); }

  void start();

  void stop();

  void receive(span<cf_t> buffer);

private:
  void send_request();

  void receive_response();

  void run_async();
};

} // namespace ocudu
