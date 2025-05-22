#!/usr/bin/env python3
import boto3
import json
from datetime import datetime

# 리전 및 설명
regions = {
    "us-east-1": "US East (N. Virginia)",
    "us-east-2": "US East (Ohio)",
    "us-west-1": "US West (N. California)",
    "us-west-2": "US West (Oregon)",
    "ap-south-1": "Asia Pacific (Mumbai)",
    "ap-northeast-1": "Asia Pacific (Tokyo)",
    "ap-northeast-2": "Asia Pacific (Seoul)",
    "ap-northeast-3": "Asia Pacific (Osaka)",
    "ap-southeast-1": "Asia Pacific (Singapore)",
    "ap-southeast-2": "Asia Pacific (Sydney)",
    "ca-central-1": "Canada (Central)",
    "sa-east-1": "South America (Sao Paulo)"
}

# EC2 인스턴스 타입
ec2_types = ["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium"]

# S3 usagetype 매핑 (일부 리전만 제공)
s3_filters = {
    "us-east-1": {"storageClass": "General Purpose", "usagetype": "TimedStorage-ByteHrs"},
    "us-east-2": {"storageClass": "General Purpose", "usagetype": "USE2-TimedStorage-ByteHrs"},
    "us-west-1": {"storageClass": "General Purpose", "usagetype": "USW1-TimedStorage-ByteHrs"},
    "us-west-2": {"storageClass": "General Purpose", "usagetype": "USW2-TimedStorage-ByteHrs"},
    "ap-south-1": {"storageClass": "General Purpose", "usagetype": "APS1-TimedStorage-ByteHrs"},
    "ap-northeast-1": {"storageClass": "General Purpose", "usagetype": "APN1-TimedStorage-ByteHrs"},
    "ap-northeast-2": {"storageClass": "General Purpose", "usagetype": "APN2-TimedStorage-ByteHrs"},
    "ap-northeast-3": {"storageClass": "General Purpose", "usagetype": "APN3-TimedStorage-ByteHrs"},
    "ap-southeast-1": {"storageClass": "General Purpose", "usagetype": "APS3-TimedStorage-ByteHrs"},
    "ap-southeast-2": {"storageClass": "General Purpose", "usagetype": "APS2-TimedStorage-ByteHrs"},
    "ca-central-1": {"storageClass": "General Purpose", "usagetype": "CAN1-TimedStorage-ByteHrs"},
    "sa-east-1": {"storageClass": "General Purpose", "usagetype": "SAE1-TimedStorage-ByteHrs"},
}

# 결과 구조 초기화
result = {region: {"ec2": {}, "rds": 0.0, "s3": 0.0} for region in regions}

# AWS Price API 클라이언트 (가격은 us-east-1에서 조회해야 함)
pricing = boto3.client("pricing", region_name="us-east-1")

# 가격 조회 함수
def get_price(service_code, filters):
    try:
        res = pricing.get_products(ServiceCode=service_code, Filters=filters, MaxResults=1)
        if not res["PriceList"]:
            return None
        product = json.loads(res["PriceList"][0])
        terms = next(iter(product["terms"]["OnDemand"].values()))
        price = float(next(iter(terms["priceDimensions"].values()))["pricePerUnit"]["USD"])
        return price
    except Exception as e:
        print(f"❗ {service_code} 가격 조회 실패: {filters} - {e}")
        return None

# 리전별 가격 조회
for region_code, location in regions.items():
    print(f"🔍 {location} 가격 조회 중...")

    # EC2
    for ec2 in ec2_types:
        price = get_price("AmazonEC2", [
            {"Type": "TERM_MATCH", "Field": "instanceType", "Value": ec2},
            {"Type": "TERM_MATCH", "Field": "location", "Value": location},
            {"Type": "TERM_MATCH", "Field": "operatingSystem", "Value": "Linux"},
            {"Type": "TERM_MATCH", "Field": "tenancy", "Value": "Shared"},
            {"Type": "TERM_MATCH", "Field": "capacitystatus", "Value": "Used"},
            {"Type": "TERM_MATCH", "Field": "preInstalledSw", "Value": "NA"}
        ])
        result[region_code]["ec2"][ec2] = round(price, 5) if price else 0.0

    # RDS
    rds_price = get_price("AmazonRDS", [
        {"Type": "TERM_MATCH", "Field": "location", "Value": location},
        {"Type": "TERM_MATCH", "Field": "instanceType", "Value": "db.t3.micro"},
        {"Type": "TERM_MATCH", "Field": "databaseEngine", "Value": "MySQL"},
        {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Database Instance"},
        {"Type": "TERM_MATCH", "Field": "deploymentOption", "Value": "Single-AZ"}
    ])
    result[region_code]["rds"] = round(rds_price, 5) if rds_price else 0.0

    # S3
    if region_code in s3_filters:
        f = s3_filters[region_code]
        s3_price = get_price("AmazonS3", [
            {"Type": "TERM_MATCH", "Field": "location", "Value": location},
            {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Storage"},
            {"Type": "TERM_MATCH", "Field": "storageClass", "Value": f["storageClass"]},
            {"Type": "TERM_MATCH", "Field": "usagetype", "Value": f["usagetype"]}
        ])
        result[region_code]["s3"] = round(s3_price, 5) if s3_price else 0.0
    else:
        print(f"⚠️ S3 필터 없음: {region_code}")

# 저장
with open("aws_price_data.json", "w") as f:
    json.dump(result, f, indent=2)

timestamp = datetime.now().strftime("[%y-%m-%d %H:%M:%S]")
print("✅ aws_price_data.json 생성 완료!")
print(f"✅ {timestamp}")

