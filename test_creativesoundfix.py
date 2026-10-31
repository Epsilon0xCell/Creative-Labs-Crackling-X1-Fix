"""Tests for creativesoundfix.sh. Run with: python3 -m unittest

The script targets macOS. These tests run on this Linux host the same
way earlier passes did: bash syntax checks, the validation paths, and
short runs with stub sleep and pkill binaries on PATH that log their
arguments and never touch a real process. Nothing here proves sound
comes back on a real Mac.
"""

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "creativesoundfix.sh"


def make_stubs(directory, pkill_exit):
    log = Path(directory) / "stub.log"
    sleep_stub = Path(directory) / "sleep"
    sleep_stub.write_text(
        "#!/bin/bash\necho \"SLEEP $@\" >> \"{}\"\n".format(log))
    pkill_stub = Path(directory) / "pkill"
    pkill_stub.write_text(
        "#!/bin/bash\necho \"PKILL $@\" >> \"{}\"\nexit {}\n".format(
            log, pkill_exit))
    for stub in (sleep_stub, pkill_stub):
        stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
    return log


def run_script(env_extra, stubs_dir, timeout=1.5):
    env = dict(os.environ)
    env["PATH"] = str(stubs_dir) + os.pathsep + env["PATH"]
    env.update(env_extra)
    return subprocess.run(
        ["bash", str(SCRIPT)], env=env, capture_output=True, text=True,
        timeout=timeout)


class SyntaxAndValidationTests(unittest.TestCase):
    def test_bash_syntax(self):
        r = subprocess.run(["bash", "-n", str(SCRIPT)],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_script_is_executable(self):
        self.assertTrue(os.access(SCRIPT, os.X_OK),
                        "creativesoundfix.sh should carry the exec bit")

    def test_non_numeric_interval_exits_1(self):
        r = run_script({"RESTART_INTERVAL_SECONDS": "abc"}, HERE)
        self.assertEqual(r.returncode, 1)
        self.assertIn("positive whole number", r.stderr)

    def test_zero_interval_exits_1(self):
        r = run_script({"RESTART_INTERVAL_SECONDS": "0"}, HERE)
        self.assertEqual(r.returncode, 1)
        self.assertIn("at least 1", r.stderr)


class StubRunTests(unittest.TestCase):
    def run_with_pkill(self, pkill_exit, env_extra):
        with tempfile.TemporaryDirectory() as d:
            log = make_stubs(d, pkill_exit)
            with self.assertRaises(subprocess.TimeoutExpired) as cm:
                run_script(env_extra, d)
            out = cm.exception.output.decode() if cm.exception.output else ""
            log_text = log.read_text() if log.exists() else ""
        return out, log_text

    def test_fixed_interval_and_success_message(self):
        out, log = self.run_with_pkill(
            0, {"RESTART_INTERVAL_SECONDS": "5"})
        self.assertIn("reset every 5 seconds", out)
        self.assertIn("Successfully sent termination signal", out)
        self.assertIn("SLEEP 5", log)
        self.assertIn("PKILL -f AudioServerDriverPlugin.app", log)

    def test_leading_zeros_normalized(self):
        out, log = self.run_with_pkill(
            0, {"RESTART_INTERVAL_SECONDS": "007"})
        self.assertIn("reset every 7 seconds", out)
        self.assertIn("SLEEP 7", log)

    def test_pkill_status_1_is_the_not_found_warning(self):
        out, _ = self.run_with_pkill(
            1, {"RESTART_INTERVAL_SECONDS": "5"})
        self.assertIn("not found. It may not have been running.", out)

    def test_pkill_status_2_names_the_failure(self):
        out, _ = self.run_with_pkill(
            2, {"RESTART_INTERVAL_SECONDS": "5"})
        self.assertIn("pkill failed with status 2", out)
        self.assertNotIn("not found. It may not have been running.", out)

    def test_random_interval_stays_in_documented_range(self):
        out, log = self.run_with_pkill(0, {})
        self.assertIn("reset every 3-5 minutes (randomized)", out)
        waits = [int(line.split()[1]) for line in log.splitlines()
                 if line.startswith("SLEEP ")]
        self.assertTrue(waits, "stub sleep was never called")
        for w in waits:
            self.assertTrue(180 <= w <= 300, w)


if __name__ == "__main__":
    unittest.main()
