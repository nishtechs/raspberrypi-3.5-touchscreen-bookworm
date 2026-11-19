#!/usr/bin/env python3
"""
Simple 480x320 System Monitor for Raspberry Pi 3.5" LCD
Built with Tkinter (no external pip dependencies required).
"""

import os
import socket
import subprocess
import time
import tkinter as tk
from tkinter import ttk


def get_ip_address():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def get_cpu_temp():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            temp = float(f.read().strip()) / 1000.0
            return f"{temp:.1f} °C"
    except Exception:
        return "N/A"


def get_cpu_usage():
    try:
        cmd = "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'"
        usage = subprocess.check_output(cmd, shell=True).decode().strip()
        return f"{float(usage):.1f} %"
    except Exception:
        return "N/A"


def get_ram_info():
    try:
        cmd = "free -m | awk 'NR==2{printf \"%s / %s MB (%.1f%%)\", $3, $2, $3*100/$2 }'"
        return subprocess.check_output(cmd, shell=True).decode().strip()
    except Exception:
        return "N/A"


def get_disk_info():
    try:
        cmd = "df -h / | awk 'NR==2{printf \"%s / %s (%s)\", $3, $2, $5}'"
        return subprocess.check_output(cmd, shell=True).decode().strip()
    except Exception:
        return "N/A"


def get_uptime():
    try:
        with open("/proc/uptime", "r") as f:
            seconds = float(f.readline().split()[0])
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            return f"{hours}h {minutes}m"
    except Exception:
        return "N/A"


class SystemMonitorApp(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("Pi Zero W Monitor")
        self.geometry("480x320")
        self.configure(bg="#1e1e2e")
        self.resizable(False, False)

        # Style definitions
        title_font = ("Helvetica", 14, "bold")
        label_font = ("Helvetica", 11, "bold")
        value_font = ("Helvetica", 11)

        # Header Frame
        header = tk.Frame(self, bg="#313244", height=40)
        header.pack(fill=tk.X)
        header.pack_propagate(False)

        lbl_title = tk.Label(
            header,
            text="⚡ Raspberry Pi Zero W - System Monitor",
            font=title_font,
            fg="#cdd6f4",
            bg="#313244",
        )
        lbl_title.pack(pady=8)

        # Content Frame
        content = tk.Frame(self, bg="#1e1e2e", padx=16, pady=10)
        content.pack(fill=tk.BOTH, expand=True)

        self.stats = [
            ("IP Address:", label_font, "#89b4fa"),
            ("CPU Usage:", label_font, "#f38ba8"),
            ("CPU Temp:", label_font, "#fab387"),
            ("RAM Usage:", label_font, "#a6e3a1"),
            ("Disk Usage:", label_font, "#f9e2af"),
            ("Uptime:", label_font, "#cba6f7"),
        ]

        self.val_labels = []

        for idx, (title, f_bold, color) in enumerate(self.stats):
            row = tk.Frame(content, bg="#1e1e2e")
            row.pack(fill=tk.X, pady=3)

            lbl = tk.Label(
                row,
                text=title,
                font=f_bold,
                fg=color,
                bg="#1e1e2e",
                width=12,
                anchor="w",
            )
            lbl.pack(side=tk.LEFT)

            val = tk.Label(
                row,
                text="Loading...",
                font=value_font,
                fg="#cdd6f4",
                bg="#1e1e2e",
                anchor="w",
            )
            val.pack(side=tk.LEFT, fill=tk.X, expand=True)
            self.val_labels.append(val)

        # Footer button
        footer = tk.Frame(self, bg="#181825", height=35)
        footer.pack(fill=tk.X, side=tk.BOTTOM)
        footer.pack_propagate(False)

        btn_quit = tk.Button(
            footer,
            text="Quit",
            command=self.destroy,
            bg="#45475a",
            fg="#cdd6f4",
            activebackground="#585b70",
            relief=tk.FLAT,
            padx=12,
        )
        btn_quit.pack(side=tk.RIGHT, padx=10, pady=4)

        self.update_stats()

    def update_stats(self):
        values = [
            get_ip_address(),
            get_cpu_usage(),
            get_cpu_temp(),
            get_ram_info(),
            get_disk_info(),
            get_uptime(),
        ]

        for lbl, val in zip(self.val_labels, values):
            lbl.config(text=val)

        # Refresh every 3 seconds
        self.after(3000, self.update_stats)


if __name__ == "__main__":
    app = SystemMonitorApp()
    app.mainloop()
