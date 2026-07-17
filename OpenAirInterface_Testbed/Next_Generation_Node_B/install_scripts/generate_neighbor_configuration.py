#!/usr/bin/env python3
#
# NIST-developed software is provided by NIST as a public service. You may use,
# copy, and distribute copies of the software in any medium, provided that you
# keep intact this entire notice. You may improve, modify, and create derivative
# works of the software or any portion of the software, and you may copy and
# distribute such modifications or works. Modified works should carry a notice
# stating that you changed the software and should note the date and nature of
# any such change. Please explicitly acknowledge the National Institute of
# Standards and Technology as the source of the software.
#
# NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
# OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
# NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
# UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
# NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
# THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
# RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
#
# You are solely responsible for determining the appropriateness of using and
# distributing the software and you assume all risks associated with its use,
# including but not limited to the risks and costs of program errors, compliance
# with applicable laws, damage to or loss of data, programs or equipment, and
# the unavailability or interruption of operation. This software is not intended
# to be used in any situation where a failure could cause risk of injury or
# damage to property. The software developed by NIST employees is not subject to
# copyright protection within the United States.

# Usage:
#   generate_neighbor_configuration.py <template> <output> <du_config> [<du_config> ...]

# For example:
#   generate_neighbor_configuration.py \
#       configs/neighbour-config-rfsim.conf \
#       configs/neighbor-config.conf \
#       configs/du1.conf configs/du2.conf configs/du3.conf

import argparse
import re
from pathlib import Path

PAIRS = {"(": ")", "{": "}", "[": "]"}


def find_matching(text, opening):
    stack = []
    quote = None
    escaped = False
    index = opening

    while index < len(text):
        char = text[index]

        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue

        if char in "\"'":
            quote = char
        elif char == "#":
            newline = text.find("\n", index)
            index = len(text) if newline == -1 else newline
            continue
        elif char == "/" and index + 1 < len(text) and text[index + 1] == "/":
            newline = text.find("\n", index)
            index = len(text) if newline == -1 else newline
            continue
        elif char in PAIRS:
            stack.append(char)
        elif char in PAIRS.values():
            if not stack or PAIRS[stack.pop()] != char:
                raise ValueError("Unbalanced configuration delimiters")
            if not stack:
                return index
        index += 1

    raise ValueError("Unterminated configuration block")


def find_assignment(text, name, opening, start=0, end=None):
    end = len(text) if end is None else end
    match = re.search(
        rf"(?m)^\s*{re.escape(name)}\s*=\s*{re.escape(opening)}", text[start:end]
    )
    if not match:
        raise ValueError(f"Configuration template does not define {name}")
    opening_index = start + match.end() - 1
    closing_index = find_matching(text, opening_index)
    return opening_index, closing_index


def first_object(text, opening, closing):
    index = opening + 1
    quote = None

    while index < closing:
        char = text[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "#":
            newline = text.find("\n", index)
            index = closing if newline == -1 else newline
            continue
        elif char == "/" and index + 1 < closing and text[index + 1] == "/":
            newline = text.find("\n", index)
            index = closing if newline == -1 else newline
            continue
        elif char == "{":
            return index, find_matching(text, index)
        index += 1

    raise ValueError("Configuration template list does not contain an object")


def indentation_at(text, index):
    line_start = text.rfind("\n", 0, index) + 1
    indentation = text[line_start:index]
    return indentation if indentation.isspace() else ""


def replace_property(text, name, value, count=1):
    pattern = re.compile(rf"(?m)^(\s*{re.escape(name)}\s*=\s*).*(;\s*(?:(?:#|//).*)?)$")
    updated, replacements = pattern.subn(
        lambda match: f"{match.group(1)}{value};", text, count=count
    )
    if replacements != count:
        raise ValueError(f"Configuration template does not define {name} as expected")
    return updated


def read_property(text, name):
    match = re.search(
        rf"(?m)^\s*{re.escape(name)}\s*=\s*(.*);\s*(?:(?:#|//).*)?$", text
    )
    if not match:
        raise ValueError(f"DU configuration does not define {name}")
    return match.group(1).strip()


def render_list(objects, object_indentation, closing_indentation):
    if not objects:
        return f"\n{closing_indentation}"
    return (
        "\n"
        + ",\n".join(f"{object_indentation}{obj}" for obj in objects)
        + f"\n{closing_indentation}"
    )


def read_du(path):
    text = path.read_text()
    plmn = read_property(text, "plmn_list")
    gnb_id = read_property(text, "gNB_DU_ID")

    def plmn_value(name):
        match = re.search(rf"\b{re.escape(name)}\s*=\s*([0-9]+)", plmn)
        if not match:
            raise ValueError(f"{path} does not define {name} in plmn_list")
        return match.group(1)

    return {
        "gnb_id": gnb_id[:-1] if gnb_id.endswith("L") else gnb_id,
        "cell_id": read_property(text, "nr_cellid"),
        "pci": read_property(text, "physCellId"),
        "ssb": read_property(text, "absoluteFrequencySSB"),
        "scs": read_property(text, "dl_subcarrierSpacing"),
        "band": read_property(text, "dl_frequencyBand"),
        "plmn": f"{{ mcc = {plmn_value('mcc')}; mnc = {plmn_value('mnc')}; mnc_length = {plmn_value('mnc_length')} }}",
        "tac": read_property(text, "tracking_area_code"),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("template", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("du_configs", nargs="+", type=Path)
    args = parser.parse_args()

    template = args.template.read_text()
    dus = [read_du(path) for path in args.du_configs]

    for key in ("gnb_id", "cell_id", "pci"):
        values = [du[key] for du in dus]
        if len(values) != len(set(values)):
            raise ValueError(f"DU configurations contain duplicate {key} values")

    list_opening, list_closing = find_assignment(template, "neighbour_list", "(")
    serving_start, serving_end = first_object(template, list_opening, list_closing)
    serving_template = template[serving_start : serving_end + 1]

    neighbor_opening, neighbor_closing = find_assignment(
        serving_template, "neighbour_cell_configuration", "("
    )
    neighbor_start, neighbor_end = first_object(
        serving_template, neighbor_opening, neighbor_closing
    )
    neighbor_template = serving_template[neighbor_start : neighbor_end + 1]
    neighbor_indentation = indentation_at(serving_template, neighbor_start)
    serving_indentation = indentation_at(template, serving_start)

    serving_objects = []
    for index, du in enumerate(dus):
        adjacent = []
        if len(dus) > 1:
            for neighbor_index in ((index - 1) % len(dus), (index + 1) % len(dus)):
                if neighbor_index != index and neighbor_index not in adjacent:
                    adjacent.append(neighbor_index)

        neighbor_objects = []
        for neighbor_index in adjacent:
            neighbor = dus[neighbor_index]
            obj = neighbor_template
            obj = replace_property(obj, "gNB_ID", neighbor["gnb_id"])
            obj = replace_property(obj, "nr_cellid", neighbor["cell_id"])
            obj = replace_property(obj, "physical_cellId", neighbor["pci"])
            obj = replace_property(obj, "absoluteFrequencySSB", neighbor["ssb"])
            obj = replace_property(obj, "subcarrierSpacing", neighbor["scs"])
            obj = replace_property(obj, "band", neighbor["band"])
            obj = replace_property(obj, "plmn", neighbor["plmn"])
            obj = replace_property(obj, "tracking_area_code", neighbor["tac"])
            neighbor_objects.append(obj)

        serving = replace_property(
            serving_template, "nr_cellid", du["cell_id"], count=1
        )
        inner_opening, inner_closing = find_assignment(
            serving, "neighbour_cell_configuration", "("
        )
        inner_indentation = indentation_at(serving, inner_closing)
        serving = (
            serving[: inner_opening + 1]
            + render_list(neighbor_objects, neighbor_indentation, inner_indentation)
            + serving[inner_closing:]
        )
        serving_objects.append(serving)

    list_indentation = indentation_at(template, list_closing)
    generated = (
        template[: list_opening + 1]
        + render_list(serving_objects, serving_indentation, list_indentation)
        + template[list_closing:]
    )
    generated = re.sub(
        r"(?m)^#.*for the 2-cell rfsim setup.*$",
        "#  Generated DU ring topology",
        generated,
    )

    measurement_opening, measurement_closing = find_assignment(
        generated, "nr_measurement_configuration", "{"
    )
    a3_opening, a3_closing = find_assignment(
        generated, "A3", "(", measurement_opening, measurement_closing
    )
    a3_start, a3_end = first_object(generated, a3_opening, a3_closing)
    a3_template = replace_property(generated[a3_start : a3_end + 1], "physCellId", "-1")
    a3_indentation = indentation_at(generated, a3_start) or indentation_at(
        generated, a3_closing
    )
    a3_closing_indentation = indentation_at(generated, a3_closing)
    generated = (
        generated[: a3_opening + 1]
        + render_list([a3_template], a3_indentation, a3_closing_indentation)
        + generated[a3_closing:]
    )

    args.output.write_text(generated)


if __name__ == "__main__":
    main()
