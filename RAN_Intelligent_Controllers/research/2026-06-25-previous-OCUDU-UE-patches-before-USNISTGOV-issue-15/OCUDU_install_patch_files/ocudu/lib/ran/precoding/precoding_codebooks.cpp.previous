// SPDX-FileCopyrightText: Copyright (C) 2021-2026 Software Radio Systems Limited
// SPDX-License-Identifier: BSD-3-Clause-Open-MPI
// Portions of this file may implement 3GPP specifications, which may be subject to additional licensing requirements.

#include "ocudu/ran/precoding/precoding_codebooks.h"
#include "ocudu/adt/interval.h"
#include "ocudu/ran/precoding/precoding_codebook_configuration.h"
#include "ocudu/ran/precoding/precoding_codebook_helpers.h"
#include "ocudu/ran/precoding/precoding_matrix_indicator.h"
#include "ocudu/support/math/math_utils.h"

using namespace ocudu;

precoding_weight_matrix ocudu::make_single_port()
{
  return make_one_layer_one_port(1, 0);
}

precoding_weight_matrix ocudu::make_one_layer_one_port(unsigned nof_ports, unsigned selected_i_port)
{
  interval<unsigned, false> selected_i_port_range(0, nof_ports);
  ocudu_assert(selected_i_port_range.contains(selected_i_port),
               "The given port identifier (i.e., {}) is out of the valid range {}",
               selected_i_port,
               selected_i_port_range);

  precoding_weight_matrix result(1, nof_ports);

  // Set weights per port.
  for (unsigned i_port = 0; i_port != nof_ports; ++i_port) {
    cf_t port_weight = (i_port == selected_i_port) ? 1.0F : 0.0F;
    result.set_coefficient(port_weight, 0, i_port);
  }

  return result;
}

precoding_weight_matrix ocudu::make_one_layer_all_ports(unsigned nof_ports)
{
  interval<unsigned, true> nof_ports_range(1, precoding_constants::MAX_NOF_PORTS);
  ocudu_assert(nof_ports_range.contains(nof_ports),
               "The number of ports (i.e., {}) is out of the valid range {}.",
               nof_ports,
               nof_ports_range);

  precoding_weight_matrix result(1, nof_ports);

  // Set normalized weights per port.
  cf_t weight = {1.0F / std::sqrt(static_cast<float>(nof_ports)), 0.0F};
  for (unsigned i_port = 0; i_port != nof_ports; ++i_port) {
    result.set_coefficient(weight, 0, i_port);
  }

  return result;
}

precoding_weight_matrix ocudu::make_identity(unsigned nof_streams)
{
  static constexpr interval<unsigned, true> nof_streams_range(1, precoding_constants::MAX_NOF_LAYERS);

  ocudu_assert(nof_streams_range.contains(nof_streams),
               "The number of streams (i.e., {}) is out of the valid range {}.",
               nof_streams,
               nof_streams_range);

  precoding_weight_matrix result(nof_streams, nof_streams);

  cf_t normalised_weight = 1.0F / std::sqrt(static_cast<float>(nof_streams));

  // Set weights per port.
  for (unsigned i_layer = 0; i_layer != nof_streams; ++i_layer) {
    for (unsigned i_port = 0; i_port != nof_streams; ++i_port) {
      cf_t weight = (i_layer == i_port) ? normalised_weight : 0.0F;
      result.set_coefficient(weight, i_layer, i_port);
    }
  }
  return result;
}

precoding_weight_matrix ocudu::make_one_layer_two_ports(unsigned i_codebook)
{
  static constexpr interval<unsigned, true>           i_codebook_range(0, 3);
  static constexpr cf_t                               sqrt_1_2         = {M_SQRT1_2, 0};
  static constexpr cf_t                               j_sqrt_1_2       = {0, M_SQRT1_2};
  static constexpr cf_t                               minus_sqrt_1_2   = {-M_SQRT1_2, 0};
  static constexpr cf_t                               minus_j_sqrt_1_2 = {0, -M_SQRT1_2};
  static constexpr std::array<std::array<cf_t, 2>, 4> codebooks        = {
      {{sqrt_1_2, sqrt_1_2}, {sqrt_1_2, j_sqrt_1_2}, {sqrt_1_2, minus_sqrt_1_2}, {sqrt_1_2, minus_j_sqrt_1_2}}};

  ocudu_assert(i_codebook_range.contains(i_codebook),
               "The given codebook identifier (i.e., {}) is out of the range {}",
               i_codebook,
               i_codebook_range);

  precoding_weight_matrix result(1, 2);

  // Select codebook.
  span<const cf_t> codebook = codebooks[i_codebook];

  // Set weights per port.
  for (unsigned i_port = 0; i_port != 2; ++i_port) {
    result.set_coefficient(codebook[i_port], 0, i_port);
  }

  return result;
}

precoding_weight_matrix ocudu::make_two_layer_two_ports(unsigned i_codebook)
{
  static constexpr interval<unsigned, true>           i_codebook_range(0, 1);
  static constexpr cf_t                               dot_five         = {0.5F, 0.0F};
  static constexpr cf_t                               minus_dot_five   = {-0.5F, 0.0F};
  static constexpr cf_t                               j_dot_five       = {0.0F, 0.5F};
  static constexpr cf_t                               minus_j_dot_five = {0.0F, -0.5F};
  static constexpr std::array<std::array<cf_t, 2>, 2> codebook0 = {{{dot_five, dot_five}, {dot_five, minus_dot_five}}};
  static constexpr std::array<std::array<cf_t, 2>, 2> codebook1 = {
      {{dot_five, j_dot_five}, {dot_five, minus_j_dot_five}}};

  ocudu_assert(i_codebook_range.contains(i_codebook),
               "The given codebook identifier (i.e., {}) is out of the range {}",
               i_codebook,
               i_codebook_range);

  precoding_weight_matrix result(2, 2);

  // Select codebook.
  const std::array<std::array<cf_t, 2>, 2>& codebook = (i_codebook == 0) ? codebook0 : codebook1;

  // Set weights per port.
  for (unsigned i_layer = 0; i_layer != 2; ++i_layer) {
    span<const cf_t> codebook_layer = codebook[i_layer];
    for (unsigned i_port = 0; i_port != 2; ++i_port) {
      result.set_coefficient(codebook_layer[i_port], i_layer, i_port);
    }
  }

  return result;
}

/// \brief Generates precoding weights for a selected layer of a Type I Single-Panel codebook, as defined in TS 38.214
/// Section 5.2.2.2.1.
///
/// The generated column follows the structure:
///
/// \f[
///   W_\text{layer} = \begin{bmatrix} \nu_{l,m} \\ \varphi_n \cdot \nu_{l,m} \end{bmatrix}
/// \f]
///
/// where \f$\nu_{l,m}\f$ is the beam steering vector and \f$\varphi_n = e^{j \cdot \text{pol\_offset\_rad}}\f$
/// is the co-phasing factor between the two cross-polarization antenna groups.
///
/// The beam steering vector \f$\nu_{l,m}\f$ is built as a Kronecker product of horizontal and vertical phase offset
/// vectors. For antenna element at horizontal position \f$i_h\f$ and vertical position \f$i_v\f$, the beam coefficient
/// is:
///
/// \f[
///   \nu_{l,m} [i_h, i_v] = e^{j 2\pi l \cdot i_h / (O_1 N_1)} \cdot e^{j 2\pi m \cdot i_v / (O_2 N_2)}
/// \f]
///
/// \note The normalization factor \f$1/\sqrt{v \cdot P_\text{CSI-RS}}\f$ (where \f$v\f$ is the number of layers
/// and \f$P_\text{CSI-RS} = 2 N_1 N_2\f$ is the number of CSI-RS ports) is not applied by this function. The caller is
/// responsible for applying it after assembling all layers.
///
/// \param[out] result Precoding weight matrix where the generated weights will be stored.
/// \param[in] panel Type I Single-Panel antenna panel information.
/// \param[in] i_layer Layer index within the precoding weight matrix.
/// \param[in] l Horizontal beam index.
/// \param[in] m Vertical beam index.
/// \param[in] polarization_offset  Cross-polarization phase offset,
static void make_layer_type1_sp_mode1(precoding_weight_matrix&              result,
                                      const pmi_codebook_single_panel_info& panel,
                                      unsigned                              i_layer,
                                      unsigned                              l,
                                      unsigned                              m,
                                      cf_t                                  polarization_offset)
{
  // Phase increment for each beam coefficient. This defines the direction of the beam in the horizontal plane.
  float phase_inc_h_rad = TWOPI * (static_cast<float>(l) / static_cast<float>(panel.o1 * panel.n1));
  // Phase increment for each beam coefficient. This defines the direction of the beam in the vertical plane.
  float phase_inc_v_rad = TWOPI * (static_cast<float>(m) / static_cast<float>(panel.o2 * panel.n2));
  // Get the number of physical ports, which is half the number of CSI-RS ports given that two polarizations are used.
  unsigned nof_ports_2 = result.get_nof_ports() / 2;

  // Phasor to increment the phase of each beam coefficient in the horizontal plane.
  cf_t phase_inc_h = std::polar(1.0F, phase_inc_h_rad);
  // Phasor to increment the phase of each beam coefficient in the vertical plane.
  cf_t phase_inc_v = std::polar(1.0F, phase_inc_v_rad);

  // Current beam coefficient in the horizontal plane. Initially set to one.
  cf_t beam_coef_h = std::polar(1.0F, 0.0F);
  // Current beam coefficient in the vertical plane. Initially set to one.
  cf_t beam_coef_v = std::polar(1.0F, 0.0F);

  // Current processed port index.
  unsigned i_port = 0;

  // Iterate every horizontal physical port.
  for (unsigned i_h = 0; i_h != panel.n1; ++i_h) {
    // Reset vertical beam coefficient.
    beam_coef_v = std::polar(1.0F, 0.0F);

    // For each horizontal port, iterate every vertical physical port.
    for (unsigned i_v = 0; i_v != panel.n2; ++i_v) {
      // Compute the beam coefficient for this port and layer.
      cf_t beam_coef = beam_coef_h * beam_coef_v;
      // First polarization.
      result.set_coefficient(beam_coef, i_layer, i_port);
      // Second polarization, same beam but with phase offset.
      result.set_coefficient(polarization_offset * beam_coef, i_layer, nof_ports_2 + i_port);

      // Increase the port index.
      i_port++;
      // Apply the phase increment to the vertical beam coefficient.
      beam_coef_v *= phase_inc_v;
    }

    // Apply the phase increment to the horizontal beam coefficient.
    beam_coef_h *= phase_inc_h;
  }
}

/// \brief Gets the parameters \f$k_1\f$ and \f$k_2\f$ as specified in TS38.214 Table 5.2.2.2.1-3.
/// \return A pair of values that correspond to \f$k_1\f$ and \f$k_2\f$.
static std::pair<unsigned, unsigned> get_k1_and_k2_2_layers(const pmi_codebook_single_panel_info& panel_info,
                                                            unsigned                              i_1_3)
{
  if (panel_info.n1 > panel_info.n2 && panel_info.n2 > 1) {
    // Case: N1 > N2 > 1.
    if (i_1_3 == 0) {
      return {0, 0};
    } else if (i_1_3 == 1) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 2) {
      return {0, panel_info.o2};
    } else if (i_1_3 == 3) {
      return {2 * panel_info.o1, 0};
    }
  } else if (panel_info.n1 == panel_info.n2) {
    // Case: N1 = N2.
    if (i_1_3 == 0) {
      return {0, 0};
    } else if (i_1_3 == 1) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 2) {
      return {0, panel_info.o2};
    } else if (i_1_3 == 3) {
      return {panel_info.o1, panel_info.o2};
    }
  } else if (panel_info.n1 == 2 && panel_info.n2 == 1) {
    // Case: N1 = 2, N2 = 1.
    // Note: The table shows empty cells for i_1_3 = 2 and 3 in this column. This implies i_1_3 is restricted to {0, 1}
    // for this specific configuration.
    if (i_1_3 == 0) {
      return {0, 0};
    } else if (i_1_3 == 1) {
      return {panel_info.o1, 0};
    }
  } else if (panel_info.n1 > 2 && panel_info.n2 == 1) {
    // Case: N1 > 2, N2 = 1.
    if (i_1_3 == 0) {
      return {0, 0};
    } else if (i_1_3 == 1) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 2) {
      return {2 * panel_info.o1, 0};
    } else if (i_1_3 == 3) {
      return {3 * panel_info.o1, 0};
    }
  }

  return {0, 0};
}

/// \brief Gets the parameters \f$k_1\f$ and \f$k_2\f$ as specified in TS38.214 Table 5.2.2.2.1-4.
///
/// Applicable to 3-layer and 4-layer CSI reporting when \f$P_\text{CSI-RS} < 16\f$.
/// \return A pair of values that correspond to \f$k_1\f$ and \f$k_2\f$.
static std::pair<unsigned, unsigned> get_k1_and_k2_3_4_layers(const pmi_codebook_single_panel_info& panel_info,
                                                              unsigned                              i_1_3)
{
  if (panel_info.n1 == 2 && panel_info.n2 == 1) {
    // Case: N1 = 2, N2 = 1. Note: The table only defines i_1_3 = 0 for this column.
    ocudu_assert(i_1_3 == 0, "For N1 = 2, N2 = 1, the parameter i_1_3 can only be 0.");
    return {panel_info.o1, 0};
  } else if (panel_info.n1 == 4 && panel_info.n2 == 1) {
    // Case: N1 = 4, N2 = 1. The table leaves i_1_3 = 3 empty for this column.
    ocudu_assert(i_1_3 <= 2, "For N1 = 4, N2 = 1, the parameter i_1_3 can only take values {0, 1, 2}.");
    if (i_1_3 == 0) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 1) {
      return {2 * panel_info.o1, 0};
    } else if (i_1_3 == 2) {
      return {3 * panel_info.o1, 0};
    }
  } else if (panel_info.n1 == 6 && panel_info.n2 == 1) {
    // Case: N1 = 6, N2 = 1.
    if (i_1_3 == 0) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 1) {
      return {2 * panel_info.o1, 0};
    } else if (i_1_3 == 2) {
      return {3 * panel_info.o1, 0};
    } else if (i_1_3 == 3) {
      return {4 * panel_info.o1, 0};
    }
  } else if (panel_info.n1 == 2 && panel_info.n2 == 2) {
    // Case: N1 = 2, N2 = 2. Note: The table leaves i_1_3 = 3 empty for this column.
    ocudu_assert(i_1_3 <= 2, "For N1 = 2, N2 = 2, the parameter i_1_3 can only take values {0, 1, 2}.");
    if (i_1_3 == 0) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 1) {
      return {0, panel_info.o2};
    } else if (i_1_3 == 2) {
      return {panel_info.o1, panel_info.o2};
    }
  } else if (panel_info.n1 == 3 && panel_info.n2 == 2) {
    // Case: N1 = 3, N2 = 2.
    if (i_1_3 == 0) {
      return {panel_info.o1, 0};
    } else if (i_1_3 == 1) {
      return {0, panel_info.o2};
    } else if (i_1_3 == 2) {
      return {panel_info.o1, panel_info.o2};
    } else if (i_1_3 == 3) {
      return {2 * panel_info.o1, 0};
    }
  }

  return {0, 0};
}

precoding_weight_matrix ocudu::make_type1_sp_mode1(const precoding_matrix_indicator& pmi, unsigned nof_layers)
{
  ocudu_assert(nof_layers <= precoding_constants::MAX_NOF_LAYERS,
               "The number of layers ({}) cannot be higher than the maximum ({}).",
               nof_layers,
               precoding_constants::MAX_NOF_LAYERS);
  ocudu_assert(nof_layers > 0, "The number of layers must be a positive number.");

  // Get the underlying Type I Single-Panel PMI type from the parameter PMI.
  const auto* type1_sp_pmi = std::get_if<pmi_typeI_single_panel>(&pmi);
  ocudu_assert(type1_sp_pmi != nullptr, "The precoding matrix indication (PMI) must be of type Type I Single-Panel.");

  // Extract the panel information.
  const pmi_codebook_single_panel_info& panel_info = get_single_panel_info(type1_sp_pmi->panel_config);
  const unsigned                        o1         = panel_info.o1;
  const unsigned                        o2         = panel_info.o2;

  // Calculate the number of CSI-RS ports.
  unsigned nof_ports = 2 * panel_info.n1 * panel_info.n2;

  // Ensure the number of ports is a supported value (positive integer below the maximum number of ports). This also
  // checks that the given Type I Single-Panel configuration is supported, i.e., N1xN2 = {2x1, 2x2, 4x1}.
  ocudu_assert(nof_ports > 0 && nof_ports <= precoding_constants::MAX_NOF_PORTS,
               "The given number of ports (i.e., {}) is out of the range of supported values ({}..{}).",
               nof_ports,
               1,
               precoding_constants::MAX_NOF_PORTS);

  // Ensure the number of layers is a supported value (positive integer below the number of ports).
  ocudu_assert(nof_layers > 0 && nof_layers <= nof_ports,
               "The given number of layers (i.e., {}) for the given number of ports (i.e., {}) is out of the range of "
               "supported values ({}..{}).",
               nof_layers,
               nof_ports,
               1,
               nof_ports);

  // Whether the antenna panel distribution is 2D, i.e., supports vertical beam selection.
  const bool is_2d_panel = panel_info.n2 > 1;

  // Get the bitwidth for the Precoding Matrix Indicator parameters given the selected panel configuration and number of
  // layers.
  pmi_typeI_single_panel_param_sizes pmi_param_sizes = get_pmi_sizes_typeI_single_panel(panel_info, nof_layers);

  // Derive the number of horizontal beams from the beam selector parameter (i_1_1) bitwidth.
  unsigned nof_beams_horizontal = pow2(pmi_param_sizes.i_1_1);
  // Derive the number of vertical beams from the beam selector parameter (i_1_2) bitwidth.
  unsigned nof_beams_vertical = pow2(pmi_param_sizes.i_1_2);
  // Derive the number of possible polarization phase shifts from the selector parameter (i_2) bitwidth.
  unsigned nof_pol_shifts = pow2(pmi_param_sizes.i_2);

  // Horizontal beam selector index.
  const unsigned i_1_1 = type1_sp_pmi->i_1_1;

  // The vertical beam selector index (i_1_2) is required when N2 > 1 (2D panel distribution).
  ocudu_assert(!is_2d_panel || type1_sp_pmi->i_1_2.has_value(),
               "Missing parameter i_1_2 for a 2D antenna panel distribution (i.e., N2 = {}).",
               panel_info.n2);
  const unsigned i_1_2 = is_2d_panel ? *type1_sp_pmi->i_1_2 : 0;

  // Validate the selected horizontal beam identifier (i_1_1).
  const interval<unsigned, false> beam_horizontal_selector_range(0, nof_beams_horizontal);
  ocudu_assert(beam_horizontal_selector_range.contains(i_1_1),
               "The given beam identifier i_1_1 (i.e., {}) is out of the range {}.",
               i_1_1,
               beam_horizontal_selector_range);

  // Validate the selected vertical beam identifier (i_1_2).
  const interval<unsigned, true> beam_vertical_selector_range(0, nof_beams_vertical);
  ocudu_assert(beam_vertical_selector_range.contains(i_1_2),
               "The given beam identifier i_1_2 (i.e., {}) is out of the range {}.",
               i_1_2,
               beam_vertical_selector_range);

  // Validate the selected polarization shift identifier (i_2).
  const interval<unsigned, false> pol_shift_selector_range(0, nof_pol_shifts);
  ocudu_assert(pol_shift_selector_range.contains(type1_sp_pmi->i_2),
               "The given polarization shift identifier i_2 (i.e., {}) is out of the range {}.",
               type1_sp_pmi->i_2,
               pol_shift_selector_range);

  // Create the resulting precoding weight matrix.
  precoding_weight_matrix result(nof_layers, nof_ports);

  // Polarization phase shift. This defines the relative phase between the cross-polarized antenna elements.
  cf_t phi = std::polar(1.0F, M_PI_2f * static_cast<float>(type1_sp_pmi->i_2));

  // Horizontal beam identifiers for each layer.
  static_vector<unsigned, precoding_constants::MAX_NOF_LAYERS> layer_beam_horizontal(nof_layers);
  // Vertical beam identifiers for each layer.
  static_vector<unsigned, precoding_constants::MAX_NOF_LAYERS> layer_beam_vertical(nof_layers);
  // Cross-polarization phase offset for each layer.
  static_vector<cf_t, precoding_constants::MAX_NOF_LAYERS> layer_pol(nof_layers);

  // Extract the i_1_3 value from the optional.
  unsigned i_1_3 = type1_sp_pmi->i_1_3.value_or(0);

  // For a 3 or 4 layer transmission using 4 antenna ports (N1 = 2, N2 = 1), the beam offset selector can only take the
  // zero value.
  if ((type1_sp_pmi->panel_config == pmi_codebook_single_panel_config::two_one) &&
      (nof_layers == 3 || nof_layers == 4)) {
    if (i_1_3 != 0) {
      ocudu_assert(*type1_sp_pmi->i_1_3 == 0,
                   "For a {} layer transmission using 4 antenna ports (N1 = 2, N2 = 1), the beam offset selector "
                   "(i_1_3) can only take the zero value.",
                   nof_layers);
    }
  }

  // Derive the number of possible beam offset selector (i_1_3) values from the parameter bitwidth.
  unsigned nof_possible_beam_offsets = pow2(pmi_param_sizes.i_1_3);

  // For a 2, 3 or 4 layer transmission, a beam offset can be applied based on i_1_3 parameter - ensure the selected
  // value is in a valid range.
  if (nof_layers >= 2 && nof_layers <= 4) {
    const interval<unsigned, false> beam_offset_range(0, nof_possible_beam_offsets);
    ocudu_assert(beam_offset_range.contains(i_1_3),
                 "The given beam offset identifier i_1_3 (i.e., {}) is out of the range {}.",
                 i_1_3,
                 beam_offset_range);
  }

  switch (nof_layers) {
    case 1: {
      // Select beam parameters from TS38.214 Table 5.2.2.2.1-5 for codebook mode 1.
      layer_beam_horizontal = {i_1_1};
      layer_beam_vertical   = {i_1_2};
      layer_pol             = {phi};
      break;
    }
    case 2: {
      // Get the offset between layers for the given panel configuration based on i_1_3, as per TS 38.214
      // Table 5.2.2.2.1-3.
      unsigned k1;
      unsigned k2;
      std::tie(k1, k2) = get_k1_and_k2_2_layers(panel_info, i_1_3);

      layer_beam_horizontal = {i_1_1, i_1_1 + k1};
      layer_beam_vertical   = {i_1_2, i_1_2 + k2};
      layer_pol             = {phi, -phi};
      break;
    }
    // Join the cases of 3 and 4 layers, they share most of the logic based on TS 38.214 Table 5.2.2.2.1-4.
    case 3:
    case 4: {
      // Get the offset between layers for the given panel configuration based on i_1_3, as per TS 38.214
      // Table 5.2.2.2.1-4.
      unsigned k1;
      unsigned k2;
      std::tie(k1, k2)      = get_k1_and_k2_3_4_layers(panel_info, i_1_3);
      layer_beam_horizontal = {i_1_1, i_1_1 + k1, i_1_1, i_1_1 + k1};
      layer_beam_vertical   = {i_1_2, i_1_2 + k2, i_1_2, i_1_2 + k2};
      layer_pol             = {phi, phi, -phi, -phi};
      break;
    }
    case 5: {
      if (is_2d_panel) {
        layer_beam_horizontal = {i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1, i_1_1 + o1};
      } else {
        layer_beam_horizontal = {i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1, i_1_1 + 2 * o1};
      }

      layer_beam_vertical = {i_1_2, i_1_2, i_1_2, i_1_2, i_1_2 + o2};
      layer_pol           = {phi, -phi, 1.0f, -1.0f, 1.0f};
      break;
    }
    case 6: {
      if (is_2d_panel) {
        layer_beam_horizontal = {i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1, i_1_1 + o1, i_1_1 + o1};
      } else {
        layer_beam_horizontal = {i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1, i_1_1 + 2 * o1, i_1_1 + 2 * o1};
      }

      layer_beam_vertical = {i_1_2, i_1_2, i_1_2, i_1_2, i_1_2 + o2, i_1_2 + o2};
      layer_pol           = {phi, -phi, phi, -phi, 1.0f, -1.0f};
      break;
    }
    case 7: {
      if (is_2d_panel) {
        layer_beam_horizontal = {i_1_1, i_1_1, i_1_1 + o1, i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1};
      } else {
        layer_beam_horizontal = {
            i_1_1, i_1_1, i_1_1 + o1, i_1_1 + 2 * o1, i_1_1 + 2 * o1, i_1_1 + 3 * o1, i_1_1 + 3 * o1};
      }

      layer_beam_vertical = {i_1_2, i_1_2, i_1_2, i_1_2 + o2, i_1_2 + o2, i_1_2 + o2, i_1_2 + o2};
      layer_pol           = {phi, -phi, phi, 1.0f, -1.0f, 1.0f, -1.0f};
      break;
    }
    case 8: {
      if (is_2d_panel) {
        layer_beam_horizontal = {i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1, i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1};
      } else {
        layer_beam_horizontal = {
            i_1_1, i_1_1, i_1_1 + o1, i_1_1 + o1, i_1_1 + 2 * o1, i_1_1 + 2 * o1, i_1_1 + 3 * o1, i_1_1 + 3 * o1};
      }

      layer_beam_vertical = {i_1_2, i_1_2, i_1_2, i_1_2, i_1_2 + o2, i_1_2 + o2, i_1_2 + o2, i_1_2 + o2};
      layer_pol           = {phi, -phi, phi, -phi, 1.0f, -1.0f, 1.0f, -1.0f};
      break;
    }
    default:
      ocudu_assert(false, "Invalid number of layers.");
  }

  // Build the coefficients for each port and layer.
  for (unsigned i_layer = 0; i_layer != nof_layers; ++i_layer) {
    make_layer_type1_sp_mode1(result,
                              panel_info,
                              i_layer,
                              layer_beam_horizontal[i_layer],
                              is_2d_panel ? layer_beam_vertical[i_layer] : 0,
                              layer_pol[i_layer]);
  }

  // Apply scaling.
  float scaling = 1.0F / std::sqrt(nof_layers * nof_ports);
  result *= scaling;

  return result;
}
