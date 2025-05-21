import json
import itertools
from diagrams import Diagram, Cluster
from diagrams.aws.compute import EC2
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.network import ELB, InternetGateway, NATGateway
from pathlib import Path

# 파일 경로
user_data_file = "/var/www/html/dlrjsgh_20250521_112331_input_data.json"
az_map_file = "/var/www/html/az_map.json"
output_dir = Path("/var/www/html/diagrams")
output_dir.mkdir(parents=True, exist_ok=True)

# 사용자 데이터 로드
with open(user_data_file) as f:
    user_data = json.load(f)

ec2_count = user_data["ec2"]
s3_count = user_data["s3"]
rds_count = user_data["rds"]
top3_regions = user_data["top3_region"]  # 리스트 형식 가정

# AZ 맵 로드
with open(az_map_file) as f:
    az_map = json.load(f)

# 다이어그램 생성 함수
def create_diagram(region, az_list, ec2, s3, rds):
    az_cycle = itertools.cycle(az_list)
    output_path = output_dir / f"{region}.png"

    with Diagram(
        f"{region} Multi-AZ Architecture",
        filename=str(output_path.with_suffix("")),
        show=False,
        graph_attr={"nodesep": "1.0", "ranksep": "5", "splines": "ortho"}
    ):
        internet_gateway = InternetGateway("Internet Gateway")
        ec2_nodes = []
        s3_nodes = []
        rds_writer = None
        rds_readers = []

        for az in az_list[:4]:  # 최대 4개 AZ까지만 표시
            with Cluster(f"{az}"):
                with Cluster("Public Subnet"):
                    lb = ELB(f"ALB-{az}")
                    nat = NATGateway(f"NAT-{az}")
                    internet_gateway >> lb
                    internet_gateway >> nat

                with Cluster("Private Subnet"):
                    ec2_per_az = [EC2(f"EC2-{i+1}") for i in range(ec2) if i % len(az_list) == az_list.index(az)]
                    ec2_nodes.extend(ec2_per_az)
                    for ec2_instance in ec2_per_az:
                        lb >> ec2_instance
                        ec2_instance >> nat

                    s3_per_az = [S3(f"S3-{i+1}") for i in range(s3) if i % len(az_list) == az_list.index(az)]
                    s3_nodes.extend(s3_per_az)

                    rds_per_az = [i for i in range(rds) if i % len(az_list) == az_list.index(az)]
                    for idx in rds_per_az:
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

# top3_region 기반으로 이미지 생성
for region in top3_regions:
    az_list = az_map.get(region, [])
    if az_list:
        create_diagram(region, az_list, ec2_count, s3_count, rds_count)

"다이어그램 생성 완료."

