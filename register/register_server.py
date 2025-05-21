from flask import Flask, request, jsonify
import os
import json

app = Flask(__name__)
USER_DIR = "users"
os.makedirs(USER_DIR, exist_ok=True)

@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    username = data["username"].strip().lower()
    password = data["password"]

    if not username or not password:
        return jsonify({"status": "error", "message": "아이디와 비밀번호를 모두 입력해주세요."})

    user_file = os.path.join(USER_DIR, f"{username}.json")

    if os.path.exists(user_file):
        return jsonify({"status": "error", "message": "이미 존재하는 아이디입니다."})

    with open(user_file, "w") as f:
        json.dump({"username": username, "password": password}, f)

    return jsonify({"status": "ok", "message": f"{username}님, 가입이 완료되었습니다!"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)

