// SPDX-FileCopyrightText: Copyright (C) 2021-2026 Software Radio Systems Limited
// SPDX-License-Identifier: BSD-3-Clause-Open-MPI

#include "sctp_network_gateway_common_impl.h"
#include "ocudu/ocudulog/ocudulog.h"
#include "ocudu/support/io/sockets.h"
#include <algorithm>
#include <netdb.h>
#include <netinet/sctp.h>
#include <sys/socket.h>

using namespace ocudu;

template <>
struct fmt::formatter<sctp_sac_state> : fmt::formatter<std::string_view> {
  auto format(sctp_sac_state v, fmt::format_context& ctx) const
  {
    std::string_view name = "UNKNOWN";
    switch (v) {
      case SCTP_COMM_UP:
        name = "SCTP_COMM_UP";
        break;
      case SCTP_COMM_LOST:
        name = "SCTP_COMM_LOST";
        break;
      case SCTP_RESTART:
        name = "SCTP_RESTART";
        break;
      case SCTP_SHUTDOWN_COMP:
        name = "SCTP_SHUTDOWN_COMP";
        break;
      case SCTP_CANT_STR_ASSOC:
        name = "SCTP_CANT_STR_ASSOC";
        break;
    }
    return fmt::formatter<std::string_view>::format(name, ctx);
  }
};

template <>
struct fmt::formatter<sctp_sn_error> : fmt::formatter<std::string_view> {
  auto format(sctp_sn_error v, fmt::format_context& ctx) const
  {
    std::string_view name = "UNKNOWN";
    switch (v) {
      case SCTP_FAILED_THRESHOLD:
        name = "SCTP_FAILED_THRESHOLD";
        break;
      case SCTP_RECEIVED_SACK:
        name = "SCTP_RECEIVED_SACK";
        break;
      case SCTP_HEARTBEAT_SUCCESS:
        name = "SCTP_HEARTBEAT_SUCCESS";
        break;
      case SCTP_RESPONSE_TO_USER_REQ:
        name = "SCTP_RESPONSE_TO_USER_REQ";
        break;
      case SCTP_INTERNAL_ERROR:
        name = "SCTP_INTERNAL_ERROR";
        break;
      case SCTP_SHUTDOWN_GUARD_EXPIRES:
        name = "SCTP_SHUTDOWN_GUARD_EXPIRES";
        break;
      case SCTP_PEER_FAULTY:
        name = "SCTP_PEER_FAULTY";
        break;
    }
    return fmt::formatter<std::string_view>::format(name, ctx);
  }
};

template <>
struct fmt::formatter<sctp_sn_type> : fmt::formatter<std::string_view> {
  auto format(sctp_sn_type v, fmt::format_context& ctx) const
  {
    std::string_view name = "UNKNOWN";
    switch (v) {
      case SCTP_DATA_IO_EVENT:
        name = "SCTP_DATA_IO_EVENT";
        break;
      case SCTP_ASSOC_CHANGE:
        name = "SCTP_ASSOC_CHANGE";
        break;
      case SCTP_PEER_ADDR_CHANGE:
        name = "SCTP_PEER_ADDR_CHANGE";
        break;
      case SCTP_SEND_FAILED:
        name = "SCTP_SEND_FAILED";
        break;
      case SCTP_REMOTE_ERROR:
        name = "SCTP_REMOTE_ERROR";
        break;
      case SCTP_SHUTDOWN_EVENT:
        name = "SCTP_SHUTDOWN_EVENT";
        break;
      case SCTP_PARTIAL_DELIVERY_EVENT:
        name = "SCTP_PARTIAL_DELIVERY_EVENT";
        break;
      case SCTP_ADAPTATION_INDICATION:
        name = "SCTP_ADAPTATION_INDICATION";
        break;
      case SCTP_AUTHENTICATION_EVENT:
        name = "SCTP_AUTHENTICATION_EVENT";
        break;
      case SCTP_SENDER_DRY_EVENT:
        name = "SCTP_SENDER_DRY_EVENT";
        break;
      case SCTP_STREAM_RESET_EVENT:
        name = "SCTP_STREAM_RESET_EVENT";
        break;
      case SCTP_ASSOC_RESET_EVENT:
        name = "SCTP_ASSOC_RESET_EVENT";
        break;
      case SCTP_STREAM_CHANGE_EVENT:
        name = "SCTP_STREAM_CHANGE_EVENT";
        break;
      case SCTP_SEND_FAILED_EVENT:
        name = "SCTP_SEND_FAILED_EVENT";
        break;
    }
    return fmt::formatter<std::string_view>::format(name, ctx);
  }
};

sockaddr_searcher::sockaddr_searcher(const std::string& address, int port, ocudulog::basic_logger& logger)
{
  struct addrinfo hints = {};
  // support ipv4, ipv6 and hostnames
  hints.ai_family    = AF_UNSPEC;
  hints.ai_socktype  = SOCK_SEQPACKET;
  hints.ai_flags     = 0;
  hints.ai_protocol  = IPPROTO_SCTP;
  hints.ai_canonname = nullptr;
  hints.ai_addr      = nullptr;
  hints.ai_next      = nullptr;

  std::string port_str = std::to_string(port);
  int         ret      = ::getaddrinfo(address.c_str(), port_str.c_str(), &hints, &results);
  if (ret != 0) {
    logger.error("Error in \"getaddrinfo\" for \"{}\":{}. Cause: {}", address, port, ::gai_strerror(ret));
    results = nullptr;
    return;
  }
  next_result = results;
}

sockaddr_searcher::~sockaddr_searcher()
{
  ::freeaddrinfo(results);
}

/// Get next candidate or nullptr of search has ended.
struct addrinfo* sockaddr_searcher::next()
{
  struct addrinfo* ret = next_result;
  if (next_result != nullptr) {
    next_result = next_result->ai_next;
  }
  return ret;
}

// class common_sctp_network_gateway_impl

sctp_network_gateway_common_impl::sctp_network_gateway_common_impl(const sctp_network_gateway_config& cfg) :
  node_cfg(cfg), logger(ocudulog::fetch_basic_logger("SCTP-GW"))
{
}

sctp_network_gateway_common_impl::~sctp_network_gateway_common_impl()
{
  close_socket();
}

bool sctp_network_gateway_common_impl::close_socket()
{
  // Stop listening to new IO Rx events.
  io_sub.reset();
  return true;
}

expected<sctp_socket> sctp_network_gateway_common_impl::create_socket(int ai_family, int ai_socktype) const
{
  sctp_socket_params params;
  params.if_name           = node_cfg.if_name;
  params.ai_family         = ai_family;
  params.ai_socktype       = ai_socktype;
  params.reuse_addr        = node_cfg.reuse_addr;
  params.non_blocking_mode = node_cfg.non_blocking_mode;
  params.rx_timeout        = std::chrono::seconds(node_cfg.rx_timeout_sec);
  params.rto_initial       = node_cfg.rto_initial;
  params.rto_min           = node_cfg.rto_min;
  params.rto_max           = node_cfg.rto_max;
  params.init_max_attempts = node_cfg.init_max_attempts;
  params.max_init_timeo    = node_cfg.max_init_timeo;
  params.hb_interval       = node_cfg.hb_interval;
  params.assoc_max_rxt     = node_cfg.assoc_max_rxt;
  params.nodelay           = node_cfg.nodelay;
  return sctp_socket::create(params);
}

/// \brief Create and bind socket to given address.
bool sctp_network_gateway_common_impl::create_and_bind_common()
{
  // Resolve all bind addresses, remove duplicates and determine required socket family.
  bool                          has_ipv6_bind_addr = false;
  std::vector<sockaddr_storage> resolved_addrs;

  for (const auto& addr : node_cfg.bind_addresses) {
    sockaddr_searcher searcher{addr, node_cfg.bind_port, logger};

    for (struct addrinfo* result = searcher.next(); result != nullptr; result = searcher.next()) {
      struct sockaddr_storage storage;
      std::memcpy(&storage, result->ai_addr, result->ai_addrlen);
      resolved_addrs.emplace_back(storage);

      if (result->ai_family == AF_INET6) {
        has_ipv6_bind_addr = true;
      }
    }
  }

  std::sort(resolved_addrs.begin(), resolved_addrs.end(), sockaddr_storage_less{});
  auto last = std::unique(resolved_addrs.begin(), resolved_addrs.end(), sockaddr_storage_equal);
  resolved_addrs.erase(last, resolved_addrs.end());

  if (resolved_addrs.empty()) {
    logger.error("Failed to resolve any bind addresses");
    return false;
  }

  // Create socket using the determined socket family.
  int socket_family = has_ipv6_bind_addr ? AF_INET6 : AF_INET;

  auto outcome = this->create_socket(socket_family, SOCK_SEQPACKET);
  if (not outcome.has_value()) {
    logger.error("Failed to create SCTP socket");
    return false;
  }

  sctp_socket& candidate = outcome.value();

  // Bind all resolved addresses using sctp_bindx.
  if (not candidate.bindx(resolved_addrs, node_cfg.bind_interface)) {
    logger.error("Failed to bind SCTP socket to {} address(es)", resolved_addrs.size());
    return false;
  }

  socket = std::move(candidate);

  if (not socket.is_open()) {
    fmt::print("Failed to create and bind SCTP socket to {} address(es). Cause: {}\n",
               resolved_addrs.size(),
               ::strerror(errno));
    return false;
  }

  return true;
}

bool sctp_network_gateway_common_impl::validate_and_log_sctp_notification(span<const uint8_t> payload) const
{
  const auto* notif             = reinterpret_cast<const union sctp_notification*>(payload.data());
  uint32_t    notif_header_size = sizeof(notif->sn_header);
  if (notif_header_size > payload.size_bytes()) {
    logger.error("{}: Received SCTP notification size ({} B) is smaller than required notification header size ({} B)",
                 node_cfg.if_name,
                 payload.size_bytes(),
                 notif_header_size);
    return false;
  }

  switch (notif->sn_header.sn_type) {
    case SCTP_ASSOC_CHANGE: {
      if (sizeof(struct sctp_assoc_change) > payload.size_bytes()) {
        logger.error("{}: Received SCTP notification SCTP_ASSOC_CHANGE size ({} B) is smaller than required struct "
                     "sctp_assoc_change size ({} B)",
                     node_cfg.if_name,
                     payload.size_bytes(),
                     sizeof(struct sctp_assoc_change));
        return false;
      }

      const struct sctp_assoc_change* n = &notif->sn_assoc_change;
      if (n->sac_state == SCTP_COMM_LOST || n->sac_state == SCTP_CANT_STR_ASSOC) {
        logger.debug("{}: Rx SCTP_ASSOC_CHANGE: sac_state={} sac_error={} sac_assoc_id={}",
                     node_cfg.if_name,
                     static_cast<sctp_sac_state>(n->sac_state),
                     static_cast<sctp_sn_error>(n->sac_error),
                     n->sac_assoc_id);
      } else {
        logger.debug("{}: Rx SCTP_ASSOC_CHANGE: sac_state={} sac_assoc_id={}",
                     node_cfg.if_name,
                     static_cast<sctp_sac_state>(n->sac_state),
                     n->sac_assoc_id);
      }
    } break;
    case SCTP_SHUTDOWN_EVENT: {
      if (sizeof(struct sctp_shutdown_event) > payload.size_bytes()) {
        logger.error("{}: Received SCTP notification SHUTDOWN_EVENT payload ({} B) is smaller than required struct "
                     "sctp_shutdown_event size ({} B)",
                     node_cfg.if_name,
                     payload.size_bytes(),
                     sizeof(struct sctp_shutdown_event));
        return false;
      }
      const struct sctp_shutdown_event* n = &notif->sn_shutdown_event;
      logger.debug("{}: Rx SCTP_SHUTDOWN_EVENT: assoc={}", node_cfg.if_name, n->sse_assoc_id);
    } break;
    default:
      logger.warning("{}: Received SCTP notification of type {} was not handled, ignoring",
                     node_cfg.if_name,
                     static_cast<sctp_sn_type>(notif->sn_header.sn_type));
      return false;
  }

  return true;
}
