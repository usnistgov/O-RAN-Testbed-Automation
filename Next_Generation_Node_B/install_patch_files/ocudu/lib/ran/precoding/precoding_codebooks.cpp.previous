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
  ocudu_assert((panel.n2 == 1) && (panel.o2 == 1),
               "Unsupported panel configuration. Only the 2x1 panel (i.e., N1 = 2, N2 = 1) is supported.");

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

  // Ensure the given panel configuration is supported.
  ocudu_assert(type1_sp_pmi->panel_config == pmi_codebook_single_panel_config::two_one,
               "For 4 CSI-RS antenna ports, only the 2x1 panel distribution is supported (i.e., N1 = 2, N2 = 1).");

  // Extract the panel information.
  const pmi_codebook_single_panel_info& panel_info = get_single_panel_info(type1_sp_pmi->panel_config);

  // Calculate the number of CSI-RS ports.
  unsigned nof_ports = 2 * panel_info.n1 * panel_info.n2;

  // Get the bitwidth for the Precoding Matrix Indicator parameters given the selected panel configuration and number of
  // layers.
  pmi_typeI_single_panel_param_sizes pmi_param_sizes = get_pmi_sizes_typeI_single_panel(panel_info, nof_layers);

  // Derive the number of beams from the beam selector parameter (i_1_1) bitwidth.
  unsigned nof_beams = pow2(pmi_param_sizes.i_1_1);

  // Number of possible polarization phase shifts given the number of layers.
  const unsigned nof_pol_shifts = (nof_layers > 1) ? 2 : 4;

  // Validate the selected horizontal beam identifier (i_1_1).
  const interval<unsigned, false> beam_selector_range(0, nof_beams);
  ocudu_assert(beam_selector_range.contains(type1_sp_pmi->i_1_1),
               "The given beam identifier i_1_1 (i.e., {}) is out of the range {}.",
               type1_sp_pmi->i_1_1,
               beam_selector_range);

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

  // Beam identifiers for each layer.
  static_vector<unsigned, precoding_constants::MAX_NOF_LAYERS> layer_beam(nof_layers);
  // Cross-polarization phase offset for each layer.
  static_vector<cf_t, precoding_constants::MAX_NOF_LAYERS> layer_pol(nof_layers);

  switch (nof_layers) {
    case 1: {
      layer_beam.assign({type1_sp_pmi->i_1_1});
      layer_pol.assign({phi});
      break;
    }
    case 2: {
      // For two layer - four antenna ports, the beam offset identifier (i.e., i_1_3) can take values 0 or 1.
      ocudu_assert(type1_sp_pmi->i_1_3.has_value(), "The PMI report is missing the beam offset identifier (i_1_3).");

      unsigned                                   i_1_3 = *type1_sp_pmi->i_1_3;
      static constexpr interval<unsigned, false> beam_offset_range(0, 2);
      ocudu_assert(beam_offset_range.contains(i_1_3),
                   "The given beam offset identifier i_1_3 (i.e., {}) is out of the range {}.",
                   i_1_3,
                   beam_offset_range);

      // Beam offset between layers, as per TS 38.214 Table 5.2.2.2.1-3 for N1=2 and N2=1.
      const std::array<unsigned, 2> k1 = {0, panel_info.o1};

      layer_beam.assign({type1_sp_pmi->i_1_1, type1_sp_pmi->i_1_1 + k1[i_1_3]});
      layer_pol.assign({phi, -phi});
      break;
    }
    case 3: {
      // Beam offset between layers, as per TS 38.214 Table 5.2.2.2.1-4.
      const unsigned k1 = panel_info.o1;

      layer_beam.assign({type1_sp_pmi->i_1_1, type1_sp_pmi->i_1_1 + k1, type1_sp_pmi->i_1_1});
      layer_pol.assign({phi, phi, -phi});
      break;
    }
    case 4: {
      // Beam offset between layers, as per TS 38.214 Table 5.2.2.2.1-4.
      const unsigned k1 = panel_info.o1;

      layer_beam.assign({type1_sp_pmi->i_1_1, type1_sp_pmi->i_1_1 + k1, type1_sp_pmi->i_1_1, type1_sp_pmi->i_1_1 + k1});
      layer_pol.assign({phi, phi, -phi, -phi});
      break;
    }
    default:
      ocudu_assert(false, "Invalid number of layers.");
      break;
  }

  // Build the coefficients for each port and layer.
  for (unsigned i_layer = 0; i_layer != nof_layers; ++i_layer) {
    make_layer_type1_sp_mode1(result, panel_info, i_layer, layer_beam[i_layer], 0, layer_pol[i_layer]);
  }

  // Apply scaling.
  float scaling = 1.0F / std::sqrt(nof_layers * nof_ports);
  result *= scaling;

  return result;
}
