import http.server
import os
import socketserver

script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
os.chdir(parent_dir)

class SingleFileHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.strip("/") != "KPI_Metrics.csv":
            self.send_error(404, "File not found")
            return
        self.path = os.path.join('logs', 'KPI_Metrics.csv')

        return super().do_GET()

PORT = 3030

class MyTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

with MyTCPServer(("", PORT), SingleFileHTTPRequestHandler) as httpd:
    print(f"Serving http://localhost:{PORT}/KPI_Metrics.csv...")
    httpd.serve_forever()
