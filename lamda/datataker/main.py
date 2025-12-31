import json
import boto3
import os
import requests
from datetime import datetime
import os 

s3 = boto3.client("s3")
sns = boto3.client("sns")

BUCKET_NAME = os.environ["BUCKET_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

API_KEY = os.environ["API_KEY"]
URL = "https://newsdata.io/api/1/latest"

params = {"apikey": API_KEY, "q": "india"}


def handler(event, context):
    # 1️⃣ Fetch news
    try:
        response = requests.get(URL, params=params, timeout=10)
        response.raise_for_status()
        api_data = response.json()
    except requests.exceptions.RequestException as e:
        print("API Error:", e)
        return {"statusCode": 500, "body": "API Failure"}

    # 2️⃣ Extract FREE fields only
    new_articles = []
    for a in api_data.get("results", []):
        new_articles.append({
            "id": a.get("article_id"),
            "title": a.get("title"),
            "description": a.get("description"),
            "link": a.get("link"),
            "source": a.get("source_name"),
            "date": a.get("pubDate")
        })

    today = datetime.utcnow().strftime("%Y-%m-%d")
    file_key = f"raw_data/daily_log_{today}.json"

    # 3️⃣ Read existing S3 file
    try:
        obj = s3.get_object(Bucket=BUCKET_NAME, Key=file_key)
        existing_data = json.loads(obj["Body"].read())
    except s3.exceptions.NoSuchKey:
        existing_data = []
    except Exception as e:
        print("S3 Read Error:", e)
        return {"statusCode": 500, "body": "S3 Read Failure"}

    # 4️⃣ Build existing article_id set
    existing_ids = set()
    for record in existing_data:
        for art in record.get("articles", []):
            existing_ids.add(art["id"])

    # 5️⃣ Deduplicate
    unique_articles = []
    for art in new_articles:
        if art["id"] not in existing_ids:
            unique_articles.append(art)

    if not unique_articles:
        print("No new articles found.")
        return {"statusCode": 200, "body": "No new data"}

    # 6️⃣ Create record
    record = {
        "timestamp": datetime.utcnow().isoformat(),
        "source": "newsdata.io",
        "count": len(unique_articles),
        "articles": unique_articles
    }

    existing_data.append(record)

    # 7️⃣ Write back to S3
    try:
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_key,
            Body=json.dumps(existing_data, indent=2),
            ContentType="application/json"
        )
    except Exception as e:
        print("S3 Write Error:", e)
        return {"statusCode": 500, "body": "S3 Write Failure"}

    # 8️⃣ SNS notification
    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"Pipeline Update: {today}",
            Message=json.dumps({
                "status": "success",
                "bucket": BUCKET_NAME,
                "key": file_key,
                "new_articles": len(unique_articles),
                "total_records": len(existing_data),
                "timestamp": datetime.utcnow().isoformat()
            })
        )
    except Exception as e:
        print("SNS Error:", e)

    return {
        "statusCode": 200,
        "body": json.dumps("Success")
    }
