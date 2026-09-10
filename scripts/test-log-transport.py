"""Exercise the real CloudWatch output against a local HTTP stub; no AWS access.

Requires Docker and the official AWS Fluent Bit image. All credentials and events
are synthetic. Only the endpoint, file locations and polling interval are local.
"""
import json
import os
from pathlib import Path
import subprocess
import ssl
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "public.ecr.aws/aws-observability/aws-for-fluent-bit:2.34.3.20260901@sha256:e6b6b5c03c7912d10757e721641046db83c80ac05796dfbdb2c16cabf7b9a331"
events = []


class CloudWatchStub(BaseHTTPRequestHandler):
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        operation = self.headers.get("X-Amz-Target", "").split(".")[-1]
        if operation == "PutLogEvents":
            events.extend((request["logGroupName"], entry["message"])
                          for entry in request["logEvents"])
        payload = json.dumps({"nextSequenceToken": "1"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/x-amz-json-1.1")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(("0.0.0.0", 0), CloudWatchStub)
server_started = False
container = f"oficina-log-test-{os.getpid()}"
try:
    with tempfile.TemporaryDirectory(prefix="oficina-log-transport-") as directory:
        work = Path(directory)
        (work / "logs").mkdir()
        (work / "state").mkdir()
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                        "-keyout", str(work / "key.pem"), "-out", str(work / "cert.pem"),
                        "-days", "1", "-subj", "/CN=host.docker.internal"],
                       check=True, capture_output=True)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(work / "cert.pem", work / "key.pem")
        server.socket = context.wrap_socket(server.socket, server_side=True)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        server_started = True
        template = (ROOT / "observability/application-log.conf.tftpl").read_text()
        header, body = template.split('%{ for environment in ["hml", "prod"] ~}')
        body = body.split("%{ endfor ~}")[0]
        config = header + "".join(body.replace("${environment}", env)
                                 for env in ("hml", "prod"))
        config = config.replace("${cluster_name}", "soat-oficina-eks")
        config = config.replace("$${READ_FROM_HEAD}", "On")
        config = config.replace("$${AWS_REGION}", "us-east-1")
        config = config.replace("$${HOST_NAME}", "local-test")
        config = config.replace("/var/log/containers", "/test/logs")
        config = config.replace("/var/fluent-bit/state", "/test/state")
        config = config.replace("Refresh_Interval    10", "Refresh_Interval    1")
        config = config.replace("Name                cloudwatch_logs",
                                "Name                cloudwatch_logs\n"
                                "    endpoint            host.docker.internal\n"
                                f"    port                {server.server_port}\n"
                                "    tls                 On\n"
                                "    tls.verify          Off")
        config = "[SERVICE]\n    Flush 1\n    storage.path /test/state\n" + config
        assert "${" not in config and "%{" not in config
        (work / "fluent-bit.conf").write_text(config)
        expected = []
        for env in ("hml", "prod", "unrelated"):
            metric = {"_aws": {"Timestamp": 1788955200000, "CloudWatchMetrics": [
                {"Namespace": "Oficina", "Dimensions": [["ServiceName", "Env"]],
                 "Metrics": [{"Name": "WorkOrdersCreated", "Unit": "Count"}]}]},
                "ServiceName": "oficina", "Env": env, "WorkOrdersCreated": 1}
            request = {"message": "request completed", "requestId": f"request-{env}",
                       "environment": env, "status": 200}
            message = json.dumps(metric, separators=(",", ":"))
            split = len(message) // 2
            lines = [f"2026-09-09T12:00:00.000000000Z stdout P {message[:split]}",
                     f"2026-09-09T12:00:00.000000001Z stdout F {message[split:]}",
                     f"2026-09-09T12:00:01.000000000Z stdout F {json.dumps(request)}"]
            (work / "logs" / f"oficina_{env}_application-123.log").write_text("\n".join(lines) + "\n")
            if env != "unrelated":
                expected.extend((f"/aws/eks/soat-oficina-eks/{env}/application", item)
                                for item in (metric, request))
        subprocess.run(["docker", "run", "--detach", "--name", container,
                        "--add-host", "host.docker.internal:host-gateway",
                        "-e", "AWS_ACCESS_KEY_ID=local-test", "-e", "AWS_SECRET_ACCESS_KEY=local-test",
                        "-e", "AWS_EC2_METADATA_DISABLED=true",
                        "--mount", f"type=bind,source={work},target=/test", IMAGE,
                        "/fluent-bit/bin/fluent-bit", "-c", "/test/fluent-bit.conf"],
                       check=True, capture_output=True, text=True)
        deadline = time.monotonic() + 45
        while len(events) < 4 and time.monotonic() < deadline:
            time.sleep(0.25)
        time.sleep(2)
        actual = [(group, json.loads(message)) for group, message in events]
        assert len(actual) == 4, f"Expected four events, received {len(actual)}"
        assert all(item in actual for item in expected), "Payload or environment routing changed"
        print("CloudWatch transport passed: root EMF, correlation fields, split CRI, hml/prod routing and namespace exclusion")
except BaseException:
    subprocess.run(["docker", "logs", container], check=False)
    raise
finally:
    subprocess.run(["docker", "rm", "--force", container], capture_output=True, check=False)
    if server_started:
        server.shutdown()
    server.server_close()
