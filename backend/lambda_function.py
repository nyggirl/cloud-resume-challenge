import json
import os
from typing import Any

import boto3


def get_table():
    """Return the DynamoDB table configured for this Lambda function."""
    table_name = os.environ["TABLE_NAME"]
    dynamodb = boto3.resource("dynamodb")
    return dynamodb.Table(table_name)


def increment_visitor_count(table: Any) -> int:
    """Atomically increment and return the visitor count."""
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

    return int(response["Attributes"]["count"])


def lambda_handler(event, context):
    table = get_table()
    visitor_count = increment_visitor_count(table)

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

def lambda_handler(event, context):
    try:
        table = get_table()
        visitor_count = increment_visitor_count(table)

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
    except Exception:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "message": "Unable to update visitor count."
            })
        }