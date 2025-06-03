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

import http.server
import os
import socketserver
import urllib.parse
import mmap
import time
import random

# Number of UEs. Send the last N samples without a step size (this is used for multi-UE scenarios to ensure that the round-robin sampling is not affected by the step size).
send_last_n_samples_no_step = 6

script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
base_dir = os.path.dirname(os.path.dirname(os.path.dirname(parent_dir)))

class SingleFileHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):

    # Perform a binary search to find the offset in the mmap file where the timestamp is greater than or equal to the target timestamp.
    def find_offset(self, mmap_file: mmap.mmap, header_end_offset: int, target_timestamp: int):
        low, high = header_end_offset, mmap_file.size()
        result_offset = mmap_file.size()

        while low < high:
            mid = (low + high) // 2
            mmap_file.seek(mid)
            # Move to the start of the next line if not at header
            if mid != header_end_offset:
                mmap_file.readline()
            current_position = mmap_file.tell()
            line = mmap_file.readline()
            if not line:
                high = mid
                continue
            try:
                timestamp = int(line.split(b',', 1)[0])
            except ValueError:
                high = mid
                continue

            if timestamp < target_timestamp:
                low = mmap_file.tell()
            else:
                result_offset = current_position
                high = mid
        # After binary search, perform a forward scan (limited number of lines)
        mmap_file.seek(result_offset)
        scan_limit = 10  # Adjust as needed
        for _ in range(scan_limit):
            pos = mmap_file.tell()
            line = mmap_file.readline()
            if not line:
                break
            try:
                ts = int(line.split(b',', 1)[0])
                if ts >= target_timestamp:
                    return pos
            except ValueError:
                continue
        # If no timestamp equal to or greater than the target was found, return the start of data (just after header)
        return header_end_offset


    def do_GET(self):
        start_time = time.perf_counter()
        
        # Parse the URL path and query string
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.lstrip('/')
        query = urllib.parse.parse_qs(parsed.query)

        # Handle requests for KPI_Metrics.csv
        if path == 'KPI_Metrics.csv':
            csv_path = os.path.join(parent_dir, 'logs', 'KPI_Metrics.csv')
            if not os.path.exists(csv_path):
                return self.send_error(404, "Not found")

            def parse_int_param(param):
                value = query.get(param, [None])[0]
                try:
                    return int(value)
                except (TypeError, ValueError):
                    return None

            from_timestamp = parse_int_param('from')
            to_timestamp = parse_int_param('to')
            approx_num_samples_param = parse_int_param('approx_num_samples')
            filter_param = query.get('filter', [None])[0]
            filter_columns = filter_param.split(',') if filter_param else None

            if approx_num_samples_param < 1: approx_num_samples_param = None

            if approx_num_samples_param and not to_timestamp:
                self.send_error(400, "Bad Request: 'num_samples' requires 'to' parameter")
                return

            # If no filters are provided, fall back to the default handler
            if from_timestamp is None and to_timestamp is None and not filter_columns:
                self.path = csv_path
                return super().do_GET()

            # Open and mmap the file for efficient access
            with open(csv_path, 'rb') as f:
                mmap_file = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
                header_end = mmap_file.find(b'\n') + 1
                start = header_end if from_timestamp is None else self.find_offset(mmap_file, header_end, from_timestamp)
                print(f"Start position for mmap: {start}")

                # If the start position is beyond the file size, return the header
                if start >= mmap_file.size():
                    header = mmap_file[:header_end]
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/csv')
                    self.send_header('Content-Length', str(len(header)))
                    self.end_headers()
                    self.wfile.write(header)
                    mmap_file.close()
                    return

                mmap_file.seek(start)

                # Always send the header row
                buffer = bytearray()
                prev_timestamp = None
                timestamp_period_estimation = None
                step_size_float = 1

                if filter_columns:
                    # Read the header and filter columns
                    header = mmap_file[:header_end]
                    header_line = header.decode().rstrip('\n').split(',')
                    column_indices = [header_line.index(col) for col in filter_columns if col in header_line]
                    filtered_header = [header_line[i] for i in column_indices]
                    filtered_bytes = (','.join(filtered_header) + '\n').encode()
                    buffer.extend(filtered_bytes)

                    mmap_file.seek(start)
                    line_count = 0
                    while True:
                        line = mmap_file.readline()
                        if not line:
                            break
                        timestamp = int(line.split(b',', 1)[0]) if line.split(b',', 1)[0].isdigit() else None

                        # Calculate the timestamp period using the first two timestamps
                        if timestamp_period_estimation is None and prev_timestamp is not None and timestamp is not None and to_timestamp is not None and approx_num_samples_param:
                            period = abs(timestamp - prev_timestamp)
                            if (period * int(approx_num_samples_param)) > 0:
                                timestamp_period_estimation = period
                                step_size_float = max(1, (to_timestamp - prev_timestamp) / (timestamp_period_estimation * int(approx_num_samples_param)))
                        if send_last_n_samples_no_step is not None:
                            # Send the last N samples at the end of the file regardless of the step size (multi-ue)
                            if timestamp_period_estimation is not None and to_timestamp is not None and timestamp is not None and abs(to_timestamp - timestamp) / timestamp_period_estimation < send_last_n_samples_no_step:
                                step_size_float = 1

                        if step_size_float == 1:
                            cells = line.rstrip(b'\r\n').split(b',')
                            filtered_line = b','.join(cells[i] for i in column_indices) + b'\n'
                            buffer.extend(filtered_line)
                        else:
                            # Probabilistically round the step size to avoid bias when step_size_float is not an integer
                            prob_step_lower = int(step_size_float)
                            prob_step_upper = prob_step_lower + 1
                            prob_step_prob_upper = step_size_float - prob_step_lower
                            prob_step_size = prob_step_upper if random.random() < prob_step_prob_upper else prob_step_lower
                            if line_count % prob_step_size == 0:
                                cells = line.rstrip(b'\r\n').split(b',')
                                filtered_line = b','.join(cells[i] for i in column_indices) + b'\n'
                                buffer.extend(filtered_line)
                        line_count += 1
                        prev_timestamp = timestamp

                        if to_timestamp is not None and timestamp is not None and timestamp > to_timestamp:
                            break
                else:
                    # If no filtering is applied, send the entire file content
                    header = mmap_file[:header_end]
                    buffer.extend(header)
                    # Read lines until the end of the file or until the to_timestamp is reached
                    line_count = 0
                    while True:
                        line = mmap_file.readline()
                        if not line:
                            break
                        timestamp = int(line.split(b',', 1)[0]) if line.split(b',', 1)[0].isdigit() else None

                        # Calculate the timestamp period using the first two timestamps
                        if timestamp_period_estimation is None and prev_timestamp is not None and timestamp is not None and to_timestamp is not None and approx_num_samples_param:
                            period = abs(timestamp - prev_timestamp)
                            if (period * int(approx_num_samples_param)) > 0:
                                timestamp_period_estimation = period
                                step_size_float = max(1, (to_timestamp - prev_timestamp) / (timestamp_period_estimation * int(approx_num_samples_param)))
                        if send_last_n_samples_no_step is not None:
                            # Send the last N samples at the end of the file regardless of the step size (multi-ue)
                            if timestamp_period_estimation is not None and to_timestamp is not None and timestamp is not None and abs(to_timestamp - timestamp) / timestamp_period_estimation < send_last_n_samples_no_step:
                                step_size_float = 1

                        if step_size_float == 1:
                            buffer.extend(line)
                        else:
                            # Probabilistically round the step size to avoid bias when step_size_float is not an integer
                            prob_step_lower = int(step_size_float)
                            prob_step_upper = prob_step_lower + 1
                            prob_step_prob_upper = step_size_float - prob_step_lower
                            prob_step_size = prob_step_upper if random.random() < prob_step_prob_upper else prob_step_lower
                            if line_count % prob_step_size == 0:
                                buffer.extend(line)
                        line_count += 1
                        prev_timestamp = timestamp

                        if to_timestamp is not None and timestamp is not None and timestamp > to_timestamp:
                            break
                
                mmap_file.close()

            data = bytes(buffer)
            # Set the response headers
            self.send_response(200)
            self.send_header('Content-Type', 'text/csv')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            
            elapsed = (time.perf_counter() - start_time) * 1000
            #print(f"{elapsed:.2f} ms")
            return

        # NIST.svg handling stays the same
        elif path == 'NIST.svg':
            self.path = os.path.join(base_dir, 'Images', 'NIST_Dark.svg')
        else:
            self.send_error(404, f'File not found: {self.path}')
            return

        if not os.path.isfile(self.path):
            self.send_error(404, f'File not found: {self.path}')
            raise Exception(f"File not found: {self.path}")

        #print(f"Serving file: {os.path.basename(self.path)}")
        result = super().do_GET()
        elapsed = (time.perf_counter() - start_time) * 1000
        #print(f"{elapsed:.2f} ms")
        return result

    # Override to serve files from the correct directory
    def translate_path(self, path):
        return os.path.abspath(self.path)
    
    # Override to add headers to prevent caching of the files
    def end_headers(self):
        # self.send_header('Cache-Control', 'no-store, must-revalidate')
        # self.send_header('Pragma', 'no-cache')
        # self.send_header('Expires', '0')

        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        return super().end_headers()

PORT = 3030

class MyTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

with MyTCPServer(('', PORT), SingleFileHTTPRequestHandler) as httpd:
    print('Serving the following routes:')
    print(f'    http://localhost:{PORT}/KPI_Metrics.csv?from=<start_ms>&to=<end_ms>&approx_num_samples=<number_of_rows>&filter=<column1,column2,...>')
    print(f'    http://localhost:{PORT}/KPI_Metrics.csv...')
    print(f'    http://localhost:{PORT}/NIST.svg...')
    httpd.serve_forever()