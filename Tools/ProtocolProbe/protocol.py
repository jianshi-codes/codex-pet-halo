"""Minimal newline-delimited JSON-RPC process transport for Codex app-server."""

from __future__ import annotations

import json
import queue
import subprocess
import threading
import time
from collections.abc import Sequence
from typing import Any

from Tools.ProtocolProbe.normalization import redact_diagnostic_text


class ProtocolError(RuntimeError):
    """The peer sent invalid or unsafe protocol data."""


class RequestTimeout(ProtocolError):
    """A JSON-RPC request did not complete before its deadline."""


class TransportClosed(ProtocolError):
    """The app-server transport closed before a request completed."""


class RemoteError(ProtocolError):
    """The app-server returned an error response."""


_CLOSED = object()


class JsonRpcProcess:
    """Own one child process and exchange generated Codex JSONL messages."""

    def __init__(self, command: Sequence[str], timeout: float = 5.0) -> None:
        if not command:
            raise ValueError("command must not be empty")
        if timeout <= 0:
            raise ValueError("timeout must be positive")
        self._command = list(command)
        self._timeout = timeout
        self._next_id = 1
        self._messages: queue.Queue[dict[str, Any] | Exception | object] = queue.Queue()
        self._notifications: list[dict[str, Any]] = []
        self._pending: dict[int | str, dict[str, Any]] = {}
        self._stderr_lines: list[str] = []
        self._process: subprocess.Popen[str] | None = None

    @property
    def notifications(self) -> list[dict[str, Any]]:
        return list(self._notifications)

    @property
    def stderr_summary(self) -> list[Any]:
        return [redact_diagnostic_text(line) for line in self._stderr_lines[-20:]]

    def start(self) -> None:
        if self._process is not None:
            raise ProtocolError("transport already started")
        try:
            self._process = subprocess.Popen(
                self._command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                bufsize=1,
            )
        except OSError as error:
            raise TransportClosed(f"unable to start transport: {error.__class__.__name__}") from error
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    def _read_stdout(self) -> None:
        assert self._process is not None and self._process.stdout is not None
        try:
            for line in self._process.stdout:
                try:
                    message = json.loads(line)
                except json.JSONDecodeError as error:
                    self._messages.put(ProtocolError(f"invalid JSON response at column {error.colno}"))
                    continue
                if not isinstance(message, dict):
                    self._messages.put(ProtocolError("protocol message must be a JSON object"))
                    continue
                self._messages.put(message)
        finally:
            self._messages.put(_CLOSED)

    def _read_stderr(self) -> None:
        assert self._process is not None and self._process.stderr is not None
        for line in self._process.stderr:
            self._stderr_lines.append(line.rstrip())

    def _write(self, message: dict[str, Any]) -> None:
        if self._process is None or self._process.stdin is None or self._process.poll() is not None:
            raise TransportClosed("transport is not running")
        try:
            self._process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            self._process.stdin.flush()
        except (BrokenPipeError, OSError) as error:
            raise TransportClosed("transport closed while sending") from error

    def notify(self, method: str) -> None:
        self._write({"method": method})

    def request(self, method: str, params: Any = None, *, include_params: bool = True) -> Any:
        request_id = self._next_id
        self._next_id += 1
        message: dict[str, Any] = {"method": method, "id": request_id}
        if include_params:
            message["params"] = params
        self._write(message)

        if request_id in self._pending:
            return self._response_result(self._pending.pop(request_id))
        deadline = time.monotonic() + self._timeout
        while True:
            incoming = self._next_message(deadline)
            if "method" in incoming:
                if "id" in incoming:
                    raise ProtocolError(f"unexpected server request: {incoming.get('method', '<unknown>')}")
                self._notifications.append(incoming)
                continue
            response_id = incoming.get("id")
            if response_id == request_id:
                return self._response_result(incoming)
            if response_id is not None:
                self._pending[response_id] = incoming

    def _response_result(self, response: dict[str, Any]) -> Any:
        if "error" in response:
            error = response.get("error")
            code = error.get("code") if isinstance(error, dict) else None
            raise RemoteError(f"app-server returned error code {code!r}")
        if "result" not in response:
            raise ProtocolError("response has neither result nor error")
        return response["result"]

    def _next_message(self, deadline: float) -> dict[str, Any]:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RequestTimeout("request timed out")
        try:
            incoming = self._messages.get(timeout=remaining)
        except queue.Empty as error:
            raise RequestTimeout("request timed out") from error
        if incoming is _CLOSED:
            raise TransportClosed("transport closed")
        if isinstance(incoming, Exception):
            raise incoming
        assert isinstance(incoming, dict)
        return incoming

    def collect_notifications(self, seconds: float) -> list[dict[str, Any]]:
        if seconds < 0:
            raise ValueError("observation duration must not be negative")
        deadline = time.monotonic() + seconds
        while seconds > 0:
            try:
                incoming = self._next_message(deadline)
            except RequestTimeout:
                break
            except TransportClosed:
                break
            if "method" in incoming and "id" not in incoming:
                self._notifications.append(incoming)
            elif incoming.get("id") is not None:
                self._pending[incoming["id"]] = incoming
        return self.notifications

    def close(self) -> None:
        process = self._process
        self._process = None
        if process is None:
            return
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream is not None:
                try:
                    stream.close()
                except OSError:
                    pass

    def __enter__(self) -> "JsonRpcProcess":
        self.start()
        return self

    def __exit__(self, _type: Any, _value: Any, _traceback: Any) -> None:
        self.close()
