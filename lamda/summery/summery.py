import json
import boto3
import os
import g4f
from g4f.client import Client

s3 = boto3.client('s3')

def handler(event, context):
    
    try:
        sns_message = event['Records'][0]['Sns']['Message']
        message_json = json.loads(sns_message)
        
        source_bucket = message_json['bucket']
        source_key = message_json['key']
        print(f"Targeting File: {source_key} in {source_bucket}")
    except (KeyError, json.JSONDecodeError) as e:
        print(f"Error parsing SNS event: {e}")
        return {"statusCode": 400, "body": "Invalid Event Format"}

    
    try:
        response = s3.get_object(Bucket=source_bucket, Key=source_key)
        file_content = response['Body'].read().decode('utf-8')
        data_json = json.loads(file_content)
        
        text_to_summarize = json.dumps(data_json[-3:]) 
    except Exception as e:
        print(f"Error reading S3: {e}")
        return {"statusCode": 500, "body": "S3 Read Failed"}

    
    try:
        client = Client()
        response = client.chat.completions.create(
            model="gemini-2.5-flash",
            messages=[{
                "role": "user", 
                "content": f"Summarize the whole:  {text_to_summarize}"
            }],
             
        )
        
        summary_text = response.choices[0].message.content
        print(f"Summary generated: {summary_text[:50]}...")
        
    except Exception as e:
        print(f"Error generating summary: {e}")
        summary_text = "Error: Could not generate summary due to API failure."


    summary_key = source_key.replace("raw_data/", "summaries/").replace(".json", "_summary.txt")
    
    try:
        s3.put_object(
            Bucket=source_bucket,
            Key=summary_key,
            Body=summary_text,
            ContentType='text/plain'
        )
        print(f"Summary saved to: {summary_key}")
    except Exception as e:
        print(f"Error saving summary to S3: {e}")
        return {"statusCode": 500, "body": "S3 Write Failed"}

    return {
        "statusCode": 200, 
        "body": "Summary process complete"
    }

