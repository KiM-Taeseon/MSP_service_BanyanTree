from flask import Flask, request, jsonify, send_from_directory
import json
import os
from datetime import datetime, timedelta

app = Flask(__name__, static_folder='.')  # 현재 디렉토리에서 정적 파일 서빙

@app.route("/")
def index():
    return send_from_directory('.', "index.nginx-debian.html")

@app.route("/<path:filename>")
def static_files(filename):
    return send_from_directory('.', filename)

@app.route("/save", methods=["POST"])
def save_input():
    data = request.get_json()
    print("📥 입력값:", data)

    user_id = data.get("id", "anonymous")  # ID 없으면 기본 anonymous

    # ✅ 한국시간(KST = UTC + 9)
    kst_time = datetime.utcnow() + timedelta(hours=9)
    timestamp = kst_time.strftime("%Y%m%d_%H%M%S")

    filename = f"{user_id}_{timestamp}_input_data.json"

    # ✅ 경로 1: 현재 디렉토리 (/var/www/html)
    path1 = os.path.join(os.path.dirname(__file__), filename)

    # ✅ 경로 2: 추가 저장 경로
    path2 = os.path.join("/root/workdir/geonho/MSP_Service_BanyanTree/geonho", filename)

    for path in [path1, path2]:
        try:
            with open(path, "w") as f:
                json.dump(data, f, indent=2)
            print(f"✅ 저장됨: {path}")
        except Exception as e:
            print(f"❌ 저장 실패 ({path}): {e}")

    return jsonify({"message": f"{filename} 저장 완료!"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

