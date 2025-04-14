import http.server
import os
import socketserver

script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
base_dir = os.path.dirname(os.path.dirname(os.path.dirname(parent_dir)))

class SingleFileHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.strip('/') == 'KPI_Metrics.csv':
            self.path = os.path.join(parent_dir, 'logs', 'KPI_Metrics.csv')
        elif self.path.strip('/') == 'NIST.svg':
            self.path = os.path.join(base_dir, 'Images', 'NIST_Dark.svg')
        else:
            self.send_error(404, f'File not found: {self.path}')
            return
        
        if not os.path.isfile(self.path):
            self.send_error(404, f'File not found: {self.path}')
            print(f"ERROR: Failed to find file at path: {self.path}")
            raise Exception(f"File not found: {self.path}")

        print(f"Serving file: {os.path.basename(self.path)}")
        return super().do_GET()

    # Override to serve files from the correct directory
    def translate_path(self, path):
        return os.path.abspath(self.path)
    
    # Override to add headers to prevent caching of the files
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        return super().end_headers()

    


PORT = 3030

class MyTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

with MyTCPServer(('', PORT), SingleFileHTTPRequestHandler) as httpd:
    print('Serving the following routes:')
    print(f'    http://localhost:{PORT}/KPI_Metrics.csv...')
    print(f'    http://localhost:{PORT}/NIST.svg...')
    httpd.serve_forever()
