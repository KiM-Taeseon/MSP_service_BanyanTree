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

    user_id = data.get("userId", "anonymous")  # ID 없으면 기본 anonymous

    # ✅ 한국시간(KST = UTC + 9)
    kst_time = datetime.utcnow() + timedelta(hours=9)
    timestamp = kst_time.strftime("%Y%m%d_%H%M%S")

    filename = f"{user_id}_{timestamp}_input_data.json"

    # ✅ 경로 1: 현재 디렉토리 (/var/www/html)
    path = os.path.join(os.path.dirname(__file__), filename)
        
    try:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        print(f"✅ 저장됨: {path}")
    except Exception as e:
        print(f"❌ 저장 실패 ({path}): {e}")

    return jsonify({"message": f"{filename} 저장 완료!"}), 200

@app.route("/final", methods=["POST"])
def save_final_input():
    data = request.get_json()
    print("📥 최종 입력값 (2단계):", data)

    # 가장 최신 input_data.json에서 user_name 추출
    input_files = [f for f in os.listdir('.') if f.endswith('_input_data.json')]
    input_files.sort(key=lambda x: os.path.getmtime(x), reverse=True)

    user_name = "anonymous"
    if input_files:
        try:
            with open(input_files[0], "r") as f:
                input_data = json.load(f)
                user_name = input_files.get("userId", "anonymous")
        except Exception as e:
            print(f"❌ user_name 추출 실패: {e}")

    # user_name을 userinput에 삽입
    if "userinput" in data:
        data["userinput"]["user_name"] = user_name

    # 파일명 생성 및 저장
    kst_time = datetime.utcnow() + timedelta(hours=9)
    timestamp = kst_time.strftime("%Y%m%d_%H%M%S")
    filename = f"{user_name}_{timestamp}_final_data.json"
    path = os.path.join(os.path.dirname(__file__), filename)

    try:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        print(f"✅ 최종 저장됨: {path}")
    except Exception as e:
        print(f"❌ 최종 저장 실패 ({path}): {e}")

    return jsonify({"message": f"{filename} 저장 완료!"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
