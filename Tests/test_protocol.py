from __future__ import annotations

import sys
import unittest

from Tools.ProtocolProbe.protocol import JsonRpcProcess, RequestTimeout, TransportClosed


class JsonRpcProcessTests(unittest.TestCase):
    def test_request_ids_and_notification_collection(self):
        script = (
            "import json,sys; "
            "a=json.loads(sys.stdin.readline()); "
            "print(json.dumps({'id':a['id'],'result':{'ok':True}}),flush=True); "
            "b=json.loads(sys.stdin.readline()); "
            "print(json.dumps({'method':'thread/status/changed','params':{'threadId':'x'}}),flush=True); "
            "print(json.dumps({'id':b['id'],'result':{'ok':True}}),flush=True)"
        )
        with JsonRpcProcess([sys.executable, "-u", "-c", script], timeout=1) as client:
            self.assertEqual(client.request("first", {}), {"ok": True})
            self.assertEqual(client.request("second", {}), {"ok": True})
            self.assertEqual(client.notifications[0]["method"], "thread/status/changed")

    def test_timeout_is_explicit(self):
        script = "import sys,time; sys.stdin.readline(); time.sleep(2)"
        with JsonRpcProcess([sys.executable, "-u", "-c", script], timeout=0.05) as client:
            with self.assertRaises(RequestTimeout):
                client.request("slow", {})

    def test_disconnect_is_explicit(self):
        script = "import sys; sys.stdin.readline(); raise SystemExit(0)"
        with JsonRpcProcess([sys.executable, "-u", "-c", script], timeout=1) as client:
            with self.assertRaises(TransportClosed):
                client.request("gone", {})


if __name__ == "__main__":
    unittest.main()
