import json
import boto3
import os
import requests  
from datetime import datetime


s3 = boto3.client('s3')
sns = boto3.client('sns')

BUCKET_NAME = os.environ.get('BUCKET_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
API_KEY = "pub_e574e1fb7b0a461e9fd28459353c7133"
url = f"https://newsdata.io/api/1/latest\?apikey\={API_KEY}\&q\=india"

def handler(event, context):
    
    
    
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status() 
        response = {"id": response["article_id"],"title": response["title"],"description": response["description"],"url": response["link"],"image": response["image_url"],"source": response["source_name"],"date": response["pubDate"]
}



        
        
        record = {
            "timestamp": datetime.now().isoformat(),
            "source": "newsdata.io",
            "data": response.json()
        }
        print("Data fetched successfully.")
    except requests.exceptions.RequestException as e:
        print(f"Error fetching API data: {e}")
        return {"statusCode": 500, "body": "API Failure"}

    
    today_str = datetime.now().strftime('%Y-%m-%d')
    file_key = f"raw_data/daily_log_{today_str}.json"

    
    current_content = []
    try:
        s3_response = s3.get_object(Bucket=BUCKET_NAME, Key=file_key)
        file_content = s3_response['Body'].read().decode('utf-8')
        current_content = json.loads(file_content)
    except s3.exceptions.NoSuchKey:
        print(f"No file found for {today_str}. Creating new file.")
        current_content = []
    except Exception as e:
        print(f"S3 Read Error: {e}")

   
    current_content.append(record)
    
    try:
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_key,
            Body=json.dumps(current_content, indent=2),
            ContentType='application/json'
        )
    except Exception as e:
        print(f"S3 Write Error: {e}")
        return {"statusCode": 500, "body": "S3 Write Failure"}

    
    message_payload = {
        "status": "success",
        "bucket": BUCKET_NAME,
        "key": file_key,
        "record_count": len(current_content),
        "timestamp": datetime.now().isoformat()
    }

    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(message_payload),
            Subject=f"Pipeline Update: {today_str}"
        )
    except Exception as e:
        print(f"SNS Error: {e}")

    return {
        "statusCode": 200, 
        "body": json.dumps("Success")
    }