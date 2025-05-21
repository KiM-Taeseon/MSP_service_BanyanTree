#!/usr/bin/env python3
import boto3
import json

# 리전 및 설명
regions = {
    "us-east-1": "US East (N. Virginia)",
    "us-west-2": "US West (Oregon)",
    "ap-northeast-1": "Asia Pacific (Tokyo)",
    "ap-northeast-2": "Asia Pacific (Seoul)",
    "ap-northeast-3": "Asia Pacific (Osaka)"
}

# EC2 인스턴스 타입
ec2_types = ["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium"]

# S3 usagetype 매핑
s3_filters = {
    "us-east-1": {"storageClass": "General Purpose", "usagetype": "TimedStorage-ByteHrs"},
    "us-west-2": {"storageClass": "General Purpose", "usagetype": "USW2-TimedStorage-ByteHrs"},
    "ap-northeast-1": {"storageClass": "General Purpose", "usagetype": "APN1-TimedStorage-ByteHrs"},
    "ap-northeast-2": {"storageClass": "General Purpose", "usagetype": "APN2-TimedStorage-ByteHrs"},
    "ap-northeast-3": {"storageClass": "General Purpose", "usagetype": "APN3-TimedStorage-ByteHrs"},
}

# 결과 저장 구조
result = {region: {"ec2": {}, "rds": 0.0, "s3": 0.0} for region in regions}

# AWS Price API 호출 함수
pricing = boto3.client("pricing", region_name="us-east-1")

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

# 각 리전별로 가격 조회
for region_code, location in regions.items():
    print(f"🔍 {location} 가격 조회 중...")

    # EC2 가격 조회
    for ec2 in ec2_types:
        price = get_price("AmazonEC2", [
            {"Type": "TERM_MATCH", "Field": "instanceType", "Value": ec2},
            {"Type": "TERM_MATCH", "Field": "location", "Value": location},
            {"Type": "TERM_MATCH", "Field": "operatingSystem", "Value": "Linux"},
            {"Type": "TERM_MATCH", "Field": "tenancy", "Value": "Shared"},
            {"Type": "TERM_MATCH", "Field": "capacitystatus", "Value": "Used"},
            {"Type": "TERM_MATCH", "Field": "preInstalledSw", "Value": "NA"}
        ])
        result[region_code]["ec2"][ec2] = price if price is not None else 0.0

    # RDS 가격 조회 (MySQL, db.t3.micro)
    rds_price = get_price("AmazonRDS", [
        {"Type": "TERM_MATCH", "Field": "location", "Value": location},
        {"Type": "TERM_MATCH", "Field": "instanceType", "Value": "db.t3.micro"},
        {"Type": "TERM_MATCH", "Field": "databaseEngine", "Value": "MySQL"},
        {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Database Instance"},
        {"Type": "TERM_MATCH", "Field": "deploymentOption", "Value": "Single-AZ"}
    ])
    result[region_code]["rds"] = rds_price if rds_price is not None else 0.0

    # S3 가격 조회 (General Purpose + 리전별 usagetype)
    s3_filter = s3_filters[region_code]
    s3_price = get_price("AmazonS3", [
        {"Type": "TERM_MATCH", "Field": "location", "Value": location},
        {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Storage"},
        {"Type": "TERM_MATCH", "Field": "storageClass", "Value": s3_filter["storageClass"]},
        {"Type": "TERM_MATCH", "Field": "usagetype", "Value": s3_filter["usagetype"]}
    ])
    result[region_code]["s3"] = s3_price if s3_price is not None else 0.0

# 결과 저장
with open("aws_price_data.json", "w") as f:
    json.dump(result, f, indent=2)

print("✅ aws_price_data.json 생성 완료!")

