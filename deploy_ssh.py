#!/usr/bin/env python3
"""
Remote deployment script for RS1535 / Waveshare 3.5" LCD on Raspberry Pi OS Bookworm.
Usage:
    python deploy_ssh.py --host 10.138.170.99 --user pi --password pi
"""

import argparse
import os
import subprocess
import sys


def run_remote_ssh(host, user, password, command):
    # Attempt using OpenSSH with SSH_ASKPASS or plink
    print(f"[*] Executing on {user}@{host}: {command[:60]}...")
    
    # On Windows, try OpenSSH with temporary askpass batch
    askpass_path = os.path.join(os.path.dirname(__file__), ".temp_askpass.bat")
    with open(askpass_path, "w") as f:
        f.write(f"@echo {password}\n")
    
    env = os.environ.copy()
    env["SSH_ASKPASS"] = askpass_path
    env["SSH_ASKPASS_REQUIRE"] = "force"
    env["DISPLAY"] = "dummy:0"
    
    try:
        proc = subprocess.run(
            [
                "ssh",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=NUL" if sys.platform == "win32" else "/dev/null",
                f"{user}@{host}",
                command
            ],
            env=env,
            capture_output=True,
            text=True
        )
        return proc.returncode, proc.stdout, proc.stderr
    finally:
        if os.path.exists(askpass_path):
            os.remove(askpass_path)


def main():
    parser = argparse.ArgumentParser(description="Deploy 3.5 LCD configuration to Raspberry Pi")
    parser.add_argument("--host", default="10.138.170.99", help="Raspberry Pi IP address")
    parser.add_argument("--user", default="pi", help="SSH username")
    parser.add_argument("--password", default="pi", help="SSH password")
    args = parser.parse_args()

    print("========================================================")
    print(f" Deploying 3.5\" LCD Configuration to {args.host}")
    print("========================================================")

    # 1. Read setup.sh script
    setup_sh_path = os.path.join(os.path.dirname(__file__), "setup.sh")
    with open(setup_sh_path, "r", encoding="utf-8") as f:
        setup_script = f.read()

    # 2. Upload and execute
    remote_cmd = (
        f"cat << 'EOF' > /tmp/setup_lcd.sh\n{setup_script}\nEOF\n"
        "chmod +x /tmp/setup_lcd.sh && sudo /tmp/setup_lcd.sh"
    )

    code, out, err = run_remote_ssh(args.host, args.user, args.password, remote_cmd)
    print(out)
    if err:
        print("[stderr]", err)

    if code == 0:
        print("[+] Deployment completed successfully!")
    else:
        print(f"[!] Deployment failed with exit code {code}")


if __name__ == "__main__":
    main()
