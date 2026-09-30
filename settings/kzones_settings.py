#!/usr/bin/env python3
"""KZones settings in QML.

KWin's own settings page for a script has to be a Qt Widgets .ui file, which cannot host QML. This is the QML
replacement: a small launcher that reads and writes the [Script-kzones] group of kwinrc (through
kreadconfig6 / kwriteconfig6, so nothing else in the file is touched) and can reload the script.

    python3 settings/kzones_settings.py      (or: make settings)
"""

import json
import os
import subprocess
import sys

from PyQt6.QtCore import QObject, QUrl, pyqtSlot
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtWidgets import QApplication

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCRIPT = "kzones"
GROUP = "Script-kzones"
_UNSET = "__kzones_unset__"


def _run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def installed_script_dir():
    for base in (os.path.expanduser("~/.local/share/kwin/scripts"), "/usr/share/kwin/scripts"):
        path = os.path.join(base, SCRIPT)
        if os.path.exists(os.path.join(path, "contents/ui/main.qml")):
            return path
    return os.path.join(ROOT, "src")


class Backend(QObject):
    @pyqtSlot(str, result=str)
    def readAll(self, keys_json):
        """{key: value} for the given keys, missing ones left out (the caller has the defaults)."""
        out = {}
        for key in json.loads(keys_json):
            r = _run("kreadconfig6", "--file", "kwinrc", "--group", GROUP, "--key", key, "--default", _UNSET)
            value = r.stdout[:-1] if r.stdout.endswith("\n") else r.stdout
            if value != _UNSET:
                out[key] = value
        return json.dumps(out)

    @pyqtSlot(str, str)
    def write(self, key, value):
        _run("kwriteconfig6", "--file", "kwinrc", "--group", GROUP, "--key", key, value)

    @pyqtSlot(result=str)
    def reload(self):
        """Unload and load the script again so it reads the new settings; returns a message for errors."""
        src = installed_script_dir()
        _run(os.path.join(ROOT, "bin/unload.sh"), SCRIPT)
        r = _run(os.path.join(ROOT, "bin/load.sh"), src, SCRIPT)
        return "" if r.returncode == 0 else (r.stderr or r.stdout).strip()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("kzones-settings")
    app.setDesktopFileName("kzones-settings")
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    # the shared color selector (colorspec/) is written for Plasma and calls KDE's i18n functions
    shims = {
        "i18n": "function (f) { return fill(f, arguments, 1); }",
        "i18nc": "function (c, f) { return fill(f, arguments, 2); }",
        "i18np": "function (one, many, n) { return fill(n === 1 ? one : many, arguments, 2); }",
    }
    fill = "function fill(f, a, from) { return String(f).replace(/%(\\d+)/g, function (m, i) { return a[from + Number(i) - 1]; }); }"
    for name, fn in shims.items():
        engine.rootContext().setContextProperty(name, engine.evaluate("(function () { %s; return %s; })()" % (fill, fn)))
    engine.load(QUrl.fromLocalFile(os.path.join(HERE, "qml/main.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
