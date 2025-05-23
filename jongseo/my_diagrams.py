import json
import itertools
from diagrams import Diagram, Cluster
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.network import ELB, InternetGateway, NATGateway
from pathlib import Path

# 입력 데이터가 있는 디렉토리 경로
input_dir = Path("/var/www/html/")

# 최신 *_input_data.json 파일 찾기
json_files = list(input_dir.glob("*_input_data.json"))
if not json_files:
    print("입력 JSON 파일이 없습니다.")
    exit(1)

user_data_file = max(json_files, key=lambda f: f.stat().st_mtime)
print(f"최신 입력 파일: {user_data_file}")

# AZ 맵 파일 경로
az_map_file = input_dir / "az_map.json"

# 출력 디렉토리 (존재하지 않으면 생성)
output_dir = input_dir / "diagrams"
output_dir.mkdir(parents=True, exist_ok=True)

# 사용자 데이터 로드
with open(user_data_file) as f:
    user_data = json.load(f)

print("\n[DEBUG] 입력 JSON 내용:")
print(json.dumps(user_data, indent=2))

ec2_count = user_data["ec2"]
s3_count = user_data["s3"]
rds_count = user_data["rds"]
top3_regions = user_data["top3_region"]  # 리스트 형식 가정

# AZ 맵 로드
with open(az_map_file) as f:
    az_map = json.load(f)

# 다이어그램 생성 함수
def create_diagram(region, az_list, ec2, s3, rds):
    output_path = output_dir / f"{region}.png"
    az_count = len(az_list)

    # 자원들을 AZ에 round-robin 방식으로 배분
    ec2_map = {az: [] for az in az_list}
    for i in range(ec2):
        target_az = az_list[i % az_count]
        ec2_map[target_az].append(f"EC2-{i+1}")

    s3_map = {az: [] for az in az_list}
    for i in range(s3):
        target_az = az_list[i % az_count]
        s3_map[target_az].append(f"S3-{i+1}")

    rds_map = {az: [] for az in az_list}
    for i in range(rds):
        target_az = az_list[i % az_count]
        rds_map[target_az].append(i)

    with Diagram(
        f"{region} Multi-AZ Architecture",
        filename=str(output_path.with_suffix("")),
        show=False,
        direction="TB",
        graph_attr={"nodesep": "1.0", "ranksep": "5", "splines": "ortho"}
    ):
        internet_gateway = InternetGateway("Internet Gateway")
        ec2_nodes = []
        s3_nodes = []
        rds_writer = None
        rds_readers = []

        for az in az_list:  # 최대 4개 AZ까지만 처리
            has_resources = ec2_map[az] or s3_map[az] or rds_map[az]
            if not has_resources:
                continue  # 자원 없는 AZ는 패스

            with Cluster(f"{az}"):
                with Cluster("Public Subnet"):
                    lb = ELB("ALB")
                    nat = NATGateway(f"NAT-{az}")
                    internet_gateway >> lb
                    internet_gateway >> nat

                with Cluster("Private Subnet"):
                    for ec2_name in ec2_map[az]:
                        ec2_instance = EC2(ec2_name)
                        ec2_nodes.append(ec2_instance)
                        lb >> ec2_instance
                        ec2_instance >> nat

                    for s3_name in s3_map[az]:
                        s3_bucket = S3(s3_name)
                        s3_nodes.append(s3_bucket)

                    for idx in rds_map[az]:
                        if rds_writer is None:
                            rds_writer = RDS("RDS-Writer")
                        else:
                            reader = RDS(f"RDS-Reader-{idx}")
                            rds_readers.append(reader)
                            reader >> rds_writer

        for ec2_instance in ec2_nodes:
            if rds_writer:
                ec2_instance >> rds_writer
            for s3 in s3_nodes:
                ec2_instance >> s3

    if output_path.exists():
        print(f"[SUCCESS] 다이어그램 저장 완료: {output_path}")
    else:
        print(f"[ERROR] 다이어그램 저장 실패 또는 누락됨: {output_path}")

# top3_region 기반으로 다이어그램 생성
for region in top3_regions:
    az_list = az_map.get(region, [])
    if az_list:
        create_diagram(region, az_list, ec2_count, s3_count, rds_count)

print("다이어그램 생성 완료.")

