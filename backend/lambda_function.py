import json
import os

import boto3


TABLE_NAME = os.environ["TABLE_NAME"]

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    response = table.update_item(
        Key={
            "id": "visitor-count"
        },
        UpdateExpression="ADD #count :increment",
        ExpressionAttributeNames={
            "#count": "count"
        },
        ExpressionAttributeValues={
            ":increment": 1
        },
        ReturnValues="UPDATED_NEW"
    )

    visitor_count = int(response["Attributes"]["count"])

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({
            "count": visitor_count
        })
    }