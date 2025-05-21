#!/usr/bin/env python3
import boto3
import json

pricing = boto3.client("pricing", region_name="us-east-1")

def get_s3_storageclass_usagetype(region_name):
    results = []

    res = pricing.get_products(
        ServiceCode="AmazonS3",
        Filters=[
            {"Type": "TERM_MATCH", "Field": "location", "Value": region_name},
            {"Type": "TERM_MATCH", "Field": "productFamily", "Value": "Storage"},
        ],
        MaxResults=100
    )

    for item in res["PriceList"]:
        product = json.loads(item)["product"]
        attrs = product.get("attributes", {})
        usagetype = attrs.get("usagetype", "")
        storage_class = attrs.get("storageClass", "")
        desc = attrs.get("description", "")
        if "TimedStorage-ByteHrs" in usagetype:
            results.append({
                "region": region_name,
                "storageClass": storage_class,
                "usagetype": usagetype,
                "description": desc
            })

    return results

# 테스트: 서울, 버지니아, 오리건 등 리전 확인
regions = [
    "Asia Pacific (Seoul)",
    "US East (N. Virginia)",
    "US West (Oregon)",
    "Asia Pacific (Tokyo)",
    "Asia Pacific (Osaka)"
]

for region in regions:
    print(f"\n🔍 {region} S3 가격 후보:")
    for entry in get_s3_storageclass_usagetype(region):
        print(f"🧾 storageClass: {entry['storageClass']} | usagetype: {entry['usagetype']}")
        print(f"   📄 {entry['description']}")

