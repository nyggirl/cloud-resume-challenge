import json
from decimal import Decimal
from unittest.mock import Mock

from backend.lambda_function import increment_visitor_count, lambda_handler


def test_increment_visitor_count_returns_updated_value():
    fake_table = Mock()
    fake_table.update_item.return_value = {
        "Attributes": {
            "count": Decimal("10")
        }
    }

    result = increment_visitor_count(fake_table)

    assert result == 10

    fake_table.update_item.assert_called_once_with(
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


def test_lambda_handler_returns_success_response(monkeypatch):
    fake_table = Mock()
    fake_table.update_item.return_value = {
        "Attributes": {
            "count": Decimal("11")
        }
    }

    monkeypatch.setattr(
        "backend.lambda_function.get_table",
        lambda: fake_table
    )

    response = lambda_handler({}, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 200
    assert response["headers"]["Content-Type"] == "application/json"
    assert response["headers"]["Access-Control-Allow-Origin"] == "*"
    assert body == {
        "count": 11
    }

def test_lambda_handler_returns_server_error(monkeypatch):
    fake_table = Mock()
    fake_table.update_item.side_effect = RuntimeError("DynamoDB unavailable")

    monkeypatch.setattr(
        "backend.lambda_function.get_table",
        lambda: fake_table
    )

    response = lambda_handler({}, None)
    body = json.loads(response["body"])

    assert response["statusCode"] == 500
    assert body == {
        "message": "Unable to update visitor count."
    }