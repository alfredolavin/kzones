"""Standalone visual editor for KZones layout JSON.

Not part of the packaged KWin script — a companion tool you run on your own
machine to build/edit the "Layouts" JSON graphically, then copy the result
into System Settings / Window Management / KWin Scripts / KZones / Layouts.
"""

import copy
import json
import sys

from PyQt6.QtCore import QPointF, QRectF, Qt
from PyQt6.QtGui import QBrush, QColor, QPainter, QPen
from PyQt6.QtWidgets import (
    QApplication,
    QComboBox,
    QDoubleSpinBox,
    QFileDialog,
    QGraphicsRectItem,
    QGraphicsScene,
    QGraphicsSceneMouseEvent,
    QGraphicsView,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QPlainTextEdit,
    QPushButton,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)

CANVAS_W = 960
CANVAS_H = 540
GRID_STEP = 5  # percent
HANDLE_SIZE = 10
ZONE_COLORS = [
    "#3daee9", "#e67e22", "#27ae60", "#9b59b6",
    "#e74c3c", "#16a085", "#f1c40f", "#2c3e50",
]

ZONE_FIELDS = {"x", "y", "width", "height"}
KNOWN_ZONE_KEYS = ZONE_FIELDS | {"applications", "color", "indicator"}
KNOWN_LAYOUT_KEYS = {"name", "padding", "zones"}


def default_layout(name="New Layout"):
    return {"name": name, "padding": 0, "zones": []}


def default_zone():
    return {"x": 25.0, "y": 25.0, "width": 50.0, "height": 50.0}


def clamp(value, lo, hi):
    return max(lo, min(hi, value))


def snap(value, step, enabled):
    if not enabled or step <= 0:
        return value
    return round(value / step) * step


class ZoneItem(QGraphicsRectItem):
    """A single zone rectangle: draggable body, resizable via corner handle."""

    def __init__(self, zone, index, editor):
        super().__init__(0, 0, 1, 1)
        self.zone = zone
        self.index = index
        self.editor = editor
        self._resizing = False
        self._syncing_pos = False
        self.setFlags(
            QGraphicsRectItem.GraphicsItemFlag.ItemIsMovable
            | QGraphicsRectItem.GraphicsItemFlag.ItemIsSelectable
            | QGraphicsRectItem.GraphicsItemFlag.ItemSendsGeometryChanges
        )
        self.setAcceptHoverEvents(True)
        self.sync_from_zone()

    def color(self):
        c = self.zone.get("color")
        if c:
            qc = QColor(c)
            if qc.isValid():
                return qc
        return QColor(ZONE_COLORS[self.index % len(ZONE_COLORS)])

    def sync_from_zone(self):
        x = self.zone["x"] / 100.0 * CANVAS_W
        y = self.zone["y"] / 100.0 * CANVAS_H
        w = self.zone["width"] / 100.0 * CANVAS_W
        h = self.zone["height"] / 100.0 * CANVAS_H
        self.setRect(0, 0, w, h)
        self._syncing_pos = True
        self.setPos(x, y)
        self._syncing_pos = False
        c = self.color()
        self.setBrush(QBrush(QColor(c.red(), c.green(), c.blue(), 110)))
        self.setPen(QPen(c, 2))
        self.update()

    def handle_rect(self):
        r = self.rect()
        return QRectF(
            r.right() - HANDLE_SIZE, r.bottom() - HANDLE_SIZE, HANDLE_SIZE, HANDLE_SIZE
        )

    def paint(self, painter: QPainter, option, widget=None):
        super().paint(painter, option, widget)
        painter.setPen(QPen(QColor("#ffffff")))
        painter.drawText(self.rect().adjusted(4, 2, -4, -2), Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft, self.zone.get("name_label", ""))
        if self.isSelected():
            painter.setBrush(QBrush(QColor("#ffffff")))
            painter.setPen(QPen(QColor("#000000")))
            painter.drawRect(self.handle_rect())

    def mousePressEvent(self, event: QGraphicsSceneMouseEvent):
        if self.handle_rect().contains(event.pos()):
            self._resizing = True
            self.editor.select_zone(self.index)
            event.accept()
            return
        self._resizing = False
        super().mousePressEvent(event)
        self.editor.select_zone(self.index)

    def mouseMoveEvent(self, event: QGraphicsSceneMouseEvent):
        if self._resizing:
            snap_on = self.editor.snap_enabled()
            new_w = clamp(event.pos().x(), HANDLE_SIZE, CANVAS_W - self.pos().x())
            new_h = clamp(event.pos().y(), HANDLE_SIZE, CANVAS_H - self.pos().y())
            pct_w = snap(new_w / CANVAS_W * 100.0, GRID_STEP, snap_on)
            pct_h = snap(new_h / CANVAS_H * 100.0, GRID_STEP, snap_on)
            self.zone["width"] = clamp(pct_w, 1, 100 - self.zone["x"])
            self.zone["height"] = clamp(pct_h, 1, 100 - self.zone["y"])
            self.sync_from_zone()
            self.editor.zone_geometry_changed(self.index)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def itemChange(self, change, value):
        if (
            change == QGraphicsRectItem.GraphicsItemChange.ItemPositionChange
            and not self._resizing
            and not self._syncing_pos
        ):
            new_pos = value
            snap_on = self.editor.snap_enabled()
            x = clamp(new_pos.x(), 0, CANVAS_W - self.rect().width())
            y = clamp(new_pos.y(), 0, CANVAS_H - self.rect().height())
            pct_x = snap(x / CANVAS_W * 100.0, GRID_STEP, snap_on)
            pct_y = snap(y / CANVAS_H * 100.0, GRID_STEP, snap_on)
            pct_x = clamp(pct_x, 0, 100 - self.zone["width"])
            pct_y = clamp(pct_y, 0, 100 - self.zone["height"])
            self.zone["x"] = pct_x
            self.zone["y"] = pct_y
            new_pos = QPointF(pct_x / 100.0 * CANVAS_W, pct_y / 100.0 * CANVAS_H)
            self.editor.zone_geometry_changed(self.index)
            return new_pos
        return super().itemChange(change, value)


class ZoneScene(QGraphicsScene):
    def __init__(self):
        super().__init__(0, 0, CANVAS_W, CANVAS_H)

    def drawBackground(self, painter: QPainter, rect: QRectF):
        painter.fillRect(rect, QColor("#1e1e1e"))
        painter.setPen(QPen(QColor("#333333")))
        step_x = CANVAS_W * GRID_STEP / 100.0
        step_y = CANVAS_H * GRID_STEP / 100.0
        x = 0.0
        while x <= CANVAS_W:
            painter.drawLine(int(x), 0, int(x), CANVAS_H)
            x += step_x
        y = 0.0
        while y <= CANVAS_H:
            painter.drawLine(0, int(y), CANVAS_W, int(y))
            y += step_y
        painter.setPen(QPen(QColor("#666666"), 2))
        painter.drawRect(QRectF(0, 0, CANVAS_W, CANVAS_H))


class ZoneEditorWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("KZones Visual Zone Editor")
        self.resize(1200, 720)

        self.layouts = [default_layout("Layout 1")]
        self.current_layout_index = 0
        self.current_zone_index = None
        self._syncing_fields = False

        self.scene = ZoneScene()
        self.view = QGraphicsView(self.scene)
        self.view.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.view.setFixedSize(CANVAS_W + 4, CANVAS_H + 4)
        self.view.setDragMode(QGraphicsView.DragMode.NoDrag)
        self.view.viewport().installEventFilter(self)
        self.scene.selectionChanged.connect(self._on_scene_selection_changed)

        self._draw_origin = None
        self._draw_item = None
        self.view.viewport().setMouseTracking(True)
        self._install_canvas_draw_handlers()

        self._build_ui()
        self.reload_layout_list()
        self.load_layout_into_scene()

    # ---- UI construction -------------------------------------------------

    def _build_ui(self):
        central = QWidget()
        root = QHBoxLayout(central)

        # Left: layout controls + canvas
        left = QVBoxLayout()
        layout_bar = QHBoxLayout()
        self.layout_combo = QComboBox()
        self.layout_combo.currentIndexChanged.connect(self.on_layout_selected)
        layout_bar.addWidget(QLabel("Layout:"))
        layout_bar.addWidget(self.layout_combo, 1)
        for text, slot in [
            ("New", self.new_layout),
            ("Rename", self.rename_layout),
            ("Duplicate", self.duplicate_layout),
            ("Delete", self.delete_layout),
        ]:
            btn = QPushButton(text)
            btn.clicked.connect(slot)
            layout_bar.addWidget(btn)
        left.addLayout(layout_bar)

        padding_bar = QHBoxLayout()
        padding_bar.addWidget(QLabel("Padding (px):"))
        self.padding_spin = QSpinBox()
        self.padding_spin.setRange(0, 500)
        self.padding_spin.valueChanged.connect(self.on_padding_changed)
        padding_bar.addWidget(self.padding_spin)
        padding_bar.addStretch(1)
        left.addLayout(padding_bar)

        left.addWidget(QLabel("Click-drag on empty space to draw a zone. Drag a zone to move it, "
                               "its bottom-right corner to resize. Arrow keys nudge the selection."))
        left.addWidget(self.view)

        canvas_actions = QHBoxLayout()
        add_zone_btn = QPushButton("Add Zone")
        add_zone_btn.clicked.connect(self.add_zone)
        del_zone_btn = QPushButton("Delete Zone")
        del_zone_btn.clicked.connect(self.delete_selected_zone)
        canvas_actions.addWidget(add_zone_btn)
        canvas_actions.addWidget(del_zone_btn)
        canvas_actions.addStretch(1)
        left.addLayout(canvas_actions)
        left.addStretch(1)

        root.addLayout(left, 3)

        # Right: zone list + fields + import/export
        right = QVBoxLayout()

        right.addWidget(QLabel("Zones in this layout:"))
        self.zone_list = QListWidget()
        self.zone_list.currentRowChanged.connect(self.on_zone_list_selected)
        right.addWidget(self.zone_list)

        fields_box = QGroupBox("Selected zone")
        grid = QGridLayout(fields_box)
        self.x_spin = self._make_pct_spin()
        self.y_spin = self._make_pct_spin()
        self.w_spin = self._make_pct_spin()
        self.h_spin = self._make_pct_spin()
        for spin in (self.x_spin, self.y_spin, self.w_spin, self.h_spin):
            spin.valueChanged.connect(self.on_field_changed)
        grid.addWidget(QLabel("X %"), 0, 0)
        grid.addWidget(self.x_spin, 0, 1)
        grid.addWidget(QLabel("Y %"), 0, 2)
        grid.addWidget(self.y_spin, 0, 3)
        grid.addWidget(QLabel("Width %"), 1, 0)
        grid.addWidget(self.w_spin, 1, 1)
        grid.addWidget(QLabel("Height %"), 1, 2)
        grid.addWidget(self.h_spin, 1, 3)

        grid.addWidget(QLabel("Applications (comma-separated)"), 2, 0, 1, 2)
        self.apps_edit = QLineEdit()
        self.apps_edit.editingFinished.connect(self.on_field_changed)
        grid.addWidget(self.apps_edit, 2, 2, 1, 2)

        grid.addWidget(QLabel("Color (name or hex, optional)"), 3, 0, 1, 2)
        self.color_edit = QLineEdit()
        self.color_edit.editingFinished.connect(self.on_field_changed)
        grid.addWidget(self.color_edit, 3, 2, 1, 2)

        right.addWidget(fields_box)

        io_box = QGroupBox("JSON")
        io_layout = QVBoxLayout(io_box)
        io_buttons = QHBoxLayout()
        import_btn = QPushButton("Import JSON…")
        import_btn.clicked.connect(self.import_json_dialog)
        import_file_btn = QPushButton("Load from File…")
        import_file_btn.clicked.connect(self.load_from_file)
        save_file_btn = QPushButton("Save to File…")
        save_file_btn.clicked.connect(self.save_to_file)
        copy_btn = QPushButton("Copy JSON to Clipboard")
        copy_btn.clicked.connect(self.copy_json)
        io_buttons.addWidget(import_btn)
        io_buttons.addWidget(import_file_btn)
        io_buttons.addWidget(save_file_btn)
        io_layout.addLayout(io_buttons)
        io_layout.addWidget(copy_btn)
        self.json_preview = QPlainTextEdit()
        self.json_preview.setReadOnly(True)
        io_layout.addWidget(self.json_preview)
        right.addWidget(io_box, 1)

        root.addLayout(right, 2)

        self.setCentralWidget(central)

    def _make_pct_spin(self):
        spin = QDoubleSpinBox()
        spin.setRange(0, 100)
        spin.setDecimals(1)
        spin.setSingleStep(1)
        return spin

    def _install_canvas_draw_handlers(self):
        self.view.viewport().installEventFilter(self)

    # ---- Layout management -------------------------------------------------

    def current_layout(self):
        return self.layouts[self.current_layout_index]

    def reload_layout_list(self):
        self.layout_combo.blockSignals(True)
        self.layout_combo.clear()
        for layout in self.layouts:
            self.layout_combo.addItem(layout["name"])
        self.layout_combo.setCurrentIndex(self.current_layout_index)
        self.layout_combo.blockSignals(False)
        self.padding_spin.blockSignals(True)
        self.padding_spin.setValue(int(self.current_layout().get("padding", 0)))
        self.padding_spin.blockSignals(False)

    def on_layout_selected(self, index):
        if index < 0:
            return
        self.current_layout_index = index
        self.current_zone_index = None
        self.reload_layout_list()
        self.load_layout_into_scene()

    def new_layout(self):
        name, ok = QInputDialog.getText(self, "New Layout", "Layout name:", text=f"Layout {len(self.layouts) + 1}")
        if not ok or not name.strip():
            return
        self.layouts.append(default_layout(name.strip()))
        self.current_layout_index = len(self.layouts) - 1
        self.reload_layout_list()
        self.load_layout_into_scene()

    def rename_layout(self):
        current = self.current_layout()
        name, ok = QInputDialog.getText(self, "Rename Layout", "Layout name:", text=current["name"])
        if ok and name.strip():
            current["name"] = name.strip()
            self.reload_layout_list()

    def duplicate_layout(self):
        current = copy.deepcopy(self.current_layout())
        current["name"] = current["name"] + " Copy"
        self.layouts.insert(self.current_layout_index + 1, current)
        self.current_layout_index += 1
        self.reload_layout_list()
        self.load_layout_into_scene()

    def delete_layout(self):
        if len(self.layouts) <= 1:
            QMessageBox.warning(self, "Cannot delete", "At least one layout is required.")
            return
        del self.layouts[self.current_layout_index]
        self.current_layout_index = max(0, self.current_layout_index - 1)
        self.reload_layout_list()
        self.load_layout_into_scene()

    def on_padding_changed(self, value):
        self.current_layout()["padding"] = value

    # ---- Zone/scene management ---------------------------------------------

    def load_layout_into_scene(self):
        self.scene.clear()
        self.zone_list.clear()
        zones = self.current_layout()["zones"]
        for i, zone in enumerate(zones):
            zone["name_label"] = f"Zone {i + 1}"
            item = ZoneItem(zone, i, self)
            self.scene.addItem(item)
            self.zone_list.addItem(QListWidgetItem(f"Zone {i + 1} ({zone['width']:.0f}x{zone['height']:.0f} @ {zone['x']:.0f},{zone['y']:.0f})"))
        self.current_zone_index = None
        self.refresh_fields()
        self.refresh_preview()

    def zone_items(self):
        return [it for it in self.scene.items() if isinstance(it, ZoneItem)]

    def refresh_zone_list_labels(self):
        for i, zone in enumerate(self.current_layout()["zones"]):
            if i < self.zone_list.count():
                self.zone_list.item(i).setText(
                    f"Zone {i + 1} ({zone['width']:.0f}x{zone['height']:.0f} @ {zone['x']:.0f},{zone['y']:.0f})"
                )

    def snap_enabled(self):
        return True

    def select_zone(self, index):
        self.current_zone_index = index
        self.zone_list.blockSignals(True)
        self.zone_list.setCurrentRow(index)
        self.zone_list.blockSignals(False)
        for it in self.zone_items():
            it.setSelected(it.index == index)
        self.refresh_fields()

    def on_zone_list_selected(self, row):
        if row < 0:
            return
        for it in self.zone_items():
            it.setSelected(it.index == row)
        self.current_zone_index = row
        self.refresh_fields()

    def _on_scene_selection_changed(self):
        selected = self.scene.selectedItems()
        if selected and isinstance(selected[0], ZoneItem):
            self.current_zone_index = selected[0].index
            self.zone_list.blockSignals(True)
            self.zone_list.setCurrentRow(self.current_zone_index)
            self.zone_list.blockSignals(False)
            self.refresh_fields()

    def zone_geometry_changed(self, index):
        self.refresh_zone_list_labels()
        if index == self.current_zone_index:
            self.refresh_fields()
        self.refresh_preview()

    def current_zone(self):
        if self.current_zone_index is None:
            return None
        zones = self.current_layout()["zones"]
        if 0 <= self.current_zone_index < len(zones):
            return zones[self.current_zone_index]
        return None

    def refresh_fields(self):
        zone = self.current_zone()
        self._syncing_fields = True
        enabled = zone is not None
        for w in (self.x_spin, self.y_spin, self.w_spin, self.h_spin, self.apps_edit, self.color_edit):
            w.setEnabled(enabled)
        if zone:
            self.x_spin.setValue(zone["x"])
            self.y_spin.setValue(zone["y"])
            self.w_spin.setValue(zone["width"])
            self.h_spin.setValue(zone["height"])
            self.apps_edit.setText(", ".join(zone.get("applications", [])))
            self.color_edit.setText(zone.get("color", "") or "")
        else:
            for w in (self.x_spin, self.y_spin, self.w_spin, self.h_spin):
                w.setValue(0)
            self.apps_edit.clear()
            self.color_edit.clear()
        self._syncing_fields = False

    def on_field_changed(self, *args):
        if self._syncing_fields:
            return
        zone = self.current_zone()
        if not zone:
            return
        zone["x"] = clamp(self.x_spin.value(), 0, 100 - self.w_spin.value())
        zone["y"] = clamp(self.y_spin.value(), 0, 100 - self.h_spin.value())
        zone["width"] = clamp(self.w_spin.value(), 1, 100 - zone["x"])
        zone["height"] = clamp(self.h_spin.value(), 1, 100 - zone["y"])
        apps = [a.strip() for a in self.apps_edit.text().split(",") if a.strip()]
        if apps:
            zone["applications"] = apps
        else:
            zone.pop("applications", None)
        color = self.color_edit.text().strip()
        if color:
            zone["color"] = color
        else:
            zone.pop("color", None)
        for it in self.zone_items():
            if it.index == self.current_zone_index:
                it.sync_from_zone()
        self.refresh_zone_list_labels()
        self.refresh_preview()

    def add_zone(self):
        zone = default_zone()
        self.current_layout()["zones"].append(zone)
        self.load_layout_into_scene()
        self.select_zone(len(self.current_layout()["zones"]) - 1)
        self.refresh_preview()

    def delete_selected_zone(self):
        if self.current_zone_index is None:
            return
        del self.current_layout()["zones"][self.current_zone_index]
        self.current_zone_index = None
        self.load_layout_into_scene()

    def add_zone_from_rect(self, x_pct, y_pct, w_pct, h_pct):
        if w_pct < 1 or h_pct < 1:
            return
        zone = {"x": x_pct, "y": y_pct, "width": w_pct, "height": h_pct}
        self.current_layout()["zones"].append(zone)
        self.load_layout_into_scene()
        self.select_zone(len(self.current_layout()["zones"]) - 1)

    # ---- Click-drag to draw a new zone on empty canvas ----------------------

    def eventFilter(self, obj, event):
        if obj is self.view.viewport():
            from PyQt6.QtCore import QEvent
            if event.type() == QEvent.Type.MouseButtonPress and event.button() == Qt.MouseButton.LeftButton:
                scene_pos = self.view.mapToScene(event.pos())
                item = self.scene.itemAt(scene_pos, self.view.transform())
                if item is None:
                    self._draw_origin = scene_pos
                    return False
            elif event.type() == QEvent.Type.MouseMove and self._draw_origin is not None:
                scene_pos = self.view.mapToScene(event.pos())
                self._update_draw_preview(self._draw_origin, scene_pos)
                return False
            elif event.type() == QEvent.Type.MouseButtonRelease and self._draw_origin is not None:
                scene_pos = self.view.mapToScene(event.pos())
                self._finish_draw(self._draw_origin, scene_pos)
                self._draw_origin = None
                return False
        return super().eventFilter(obj, event)

    def _rect_from_drag(self, origin, current):
        x0 = clamp(min(origin.x(), current.x()), 0, CANVAS_W)
        y0 = clamp(min(origin.y(), current.y()), 0, CANVAS_H)
        x1 = clamp(max(origin.x(), current.x()), 0, CANVAS_W)
        y1 = clamp(max(origin.y(), current.y()), 0, CANVAS_H)
        return QRectF(x0, y0, x1 - x0, y1 - y0)

    def _update_draw_preview(self, origin, current):
        rect = self._rect_from_drag(origin, current)
        if self._draw_item is None:
            self._draw_item = self.scene.addRect(rect, QPen(QColor("#ffffff"), 1, Qt.PenStyle.DashLine))
        else:
            self._draw_item.setRect(rect)

    def _finish_draw(self, origin, current):
        rect = self._rect_from_drag(origin, current)
        if self._draw_item is not None:
            self.scene.removeItem(self._draw_item)
            self._draw_item = None
        if rect.width() < 5 or rect.height() < 5:
            return
        snap_on = self.snap_enabled()
        x_pct = snap(rect.x() / CANVAS_W * 100.0, GRID_STEP, snap_on)
        y_pct = snap(rect.y() / CANVAS_H * 100.0, GRID_STEP, snap_on)
        w_pct = snap(rect.width() / CANVAS_W * 100.0, GRID_STEP, snap_on)
        h_pct = snap(rect.height() / CANVAS_H * 100.0, GRID_STEP, snap_on)
        w_pct = max(w_pct, GRID_STEP)
        h_pct = max(h_pct, GRID_STEP)
        self.add_zone_from_rect(x_pct, y_pct, min(w_pct, 100 - x_pct), min(h_pct, 100 - y_pct))

    # ---- Keyboard nudging ----------------------------------------------------

    def keyPressEvent(self, event):
        zone = self.current_zone()
        if zone is None:
            return super().keyPressEvent(event)
        step = 5 if event.modifiers() & Qt.KeyboardModifier.ShiftModifier else 1
        dx = dy = 0
        if event.key() == Qt.Key.Key_Left:
            dx = -step
        elif event.key() == Qt.Key.Key_Right:
            dx = step
        elif event.key() == Qt.Key.Key_Up:
            dy = -step
        elif event.key() == Qt.Key.Key_Down:
            dy = step
        elif event.key() in (Qt.Key.Key_Delete, Qt.Key.Key_Backspace):
            self.delete_selected_zone()
            return
        else:
            return super().keyPressEvent(event)
        zone["x"] = clamp(zone["x"] + dx, 0, 100 - zone["width"])
        zone["y"] = clamp(zone["y"] + dy, 0, 100 - zone["height"])
        for it in self.zone_items():
            if it.index == self.current_zone_index:
                it.sync_from_zone()
        self.refresh_zone_list_labels()
        self.refresh_fields()
        self.refresh_preview()

    # ---- JSON import/export -------------------------------------------------

    def layouts_to_json_str(self):
        clean = []
        for layout in self.layouts:
            out_layout = {k: v for k, v in layout.items() if k != "zones"}
            out_zones = []
            for zone in layout["zones"]:
                out_zone = {k: v for k, v in zone.items() if k != "name_label"}
                out_zones.append(out_zone)
            out_layout["zones"] = out_zones
            clean.append(out_layout)
        return json.dumps(clean, indent=2)

    def refresh_preview(self):
        self.json_preview.setPlainText(self.layouts_to_json_str())

    def validate_layouts(self, layouts):
        for layout in layouts:
            if not layout.get("name", "").strip():
                return "Every layout needs a non-empty name."
            for zone in layout.get("zones", []):
                if zone.get("x", 0) + zone.get("width", 0) > 100.001:
                    return f"Zone in '{layout['name']}' extends past the right edge (x + width > 100)."
                if zone.get("y", 0) + zone.get("height", 0) > 100.001:
                    return f"Zone in '{layout['name']}' extends past the bottom edge (y + height > 100)."
        return None

    def load_layouts(self, data):
        if not isinstance(data, list):
            raise ValueError("Top-level JSON must be an array of layouts.")
        layouts = []
        for raw_layout in data:
            layout = dict(raw_layout)
            layout.setdefault("name", "Layout")
            layout.setdefault("padding", 0)
            zones = []
            for raw_zone in layout.get("zones", []):
                zone = dict(raw_zone)
                for key in ("x", "y", "width", "height"):
                    zone[key] = float(zone.get(key, 0))
                zones.append(zone)
            layout["zones"] = zones
            layouts.append(layout)
        if not layouts:
            layouts = [default_layout()]
        error = self.validate_layouts(layouts)
        if error:
            raise ValueError(error)
        self.layouts = layouts
        self.current_layout_index = 0
        self.current_zone_index = None
        self.reload_layout_list()
        self.load_layout_into_scene()

    def import_json_dialog(self):
        dialog = QPlainTextEdit()
        from PyQt6.QtWidgets import QDialog, QDialogButtonBox
        d = QDialog(self)
        d.setWindowTitle("Import Layouts JSON")
        d.resize(600, 400)
        layout = QVBoxLayout(d)
        layout.addWidget(QLabel("Paste your Layouts JSON below (e.g. copied from KZones' config dialog):"))
        layout.addWidget(dialog)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(d.accept)
        buttons.rejected.connect(d.reject)
        layout.addWidget(buttons)
        if d.exec() == QDialog.DialogCode.Accepted:
            text = dialog.toPlainText().strip()
            if not text:
                return
            try:
                data = json.loads(text)
                self.load_layouts(data)
            except (json.JSONDecodeError, ValueError) as e:
                QMessageBox.critical(self, "Import failed", str(e))

    def load_from_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "Load Layouts JSON", "", "JSON Files (*.json);;All Files (*)")
        if not path:
            return
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.load_layouts(data)
        except (OSError, json.JSONDecodeError, ValueError) as e:
            QMessageBox.critical(self, "Load failed", str(e))

    def save_to_file(self):
        error = self.validate_layouts(self.layouts)
        if error:
            QMessageBox.warning(self, "Fix before saving", error)
            return
        path, _ = QFileDialog.getSaveFileName(self, "Save Layouts JSON", "layouts.json", "JSON Files (*.json)")
        if not path:
            return
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(self.layouts_to_json_str())
        except OSError as e:
            QMessageBox.critical(self, "Save failed", str(e))

    def copy_json(self):
        error = self.validate_layouts(self.layouts)
        if error:
            QMessageBox.warning(self, "Fix before copying", error)
            return
        QApplication.clipboard().setText(self.layouts_to_json_str())
        self.statusBar().showMessage("Layouts JSON copied to clipboard.", 3000)


def main():
    app = QApplication(sys.argv)
    window = ZoneEditorWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
