import time
import subprocess
import json # For final_input.json
import requests # For final_input.json
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

WATCH_DIR = Path.cwd()  # 현재 폴더 감시

class InputFileHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        filepath = Path(event.src_path)
        if filepath.name.endswith("input_data.json"):
            print(f"[INFO] Detected new file: {filepath.name} — Running my_diagrams.py")
            try:
                subprocess.run(["python3", "my_diagrams.py"], check=True)
                print("[SUCCESS] Diagram generation completed.")
            except subprocess.CalledProcessError as e:
                print(f"[ERROR] Failed to run my_diagrams.py: {e}")
        
        # For final_input.json
        elif filepath.name.endswith("final_data.json"):
            print(f"[INFO] Detected new file: {filepath.name} — Sending to webhook")

            try:
                with open(filepath, "r") as f:
                    data = json.load(f)

                response = requests.post(
                    "http://3.35.235.224:8081/build-project",  # 필요 시 EC2 IP로 변경
                    headers={"Content-Type": "application/json"},
                    json=data
                )

                if response.status_code == 200 or response.status_code == 202:
                    print(f"[SUCCESS] Sent to webhook: {response.status_code}")
                else:
                    print(f"[ERROR] Webhook response: {response.status_code} - {response.text}")

            except Exception as e:
                print(f"[ERROR] Failed to send webhook: {e}")

if __name__ == "__main__":
    print(f"[WATCHING] Folder: {WATCH_DIR} for new *input_data.json or final_data.json files")
    event_handler = InputFileHandler()
    observer = Observer()
    observer.schedule(event_handler, str(WATCH_DIR), recursive=False)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
