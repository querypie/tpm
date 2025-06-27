#!/usr/bin/env python3
"""
서버 프로세서 테스트
"""

import unittest
import tempfile
import os
from unittest.mock import patch, MagicMock
from server_processor import process_server_csv, ServerProcessor

class TestServerProcessor(unittest.TestCase):
    """ServerProcessor 클래스 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"
        self.processor = ServerProcessor(self.api_url, self.api_key)

    @patch('requests.get')
    def test_server_exists(self, mock_get):
        """server_exists 메서드 테스트"""
        # 서버가 존재하는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [{"server": {"name": "existing_server", "uuid": "server-uuid"}}],
            "page": {"totalElements": 1}
        }
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.processor.server_exists("existing_server")

        # 결과 확인
        self.assertEqual(result, "server-uuid")
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/servers?name=existing_server",
            headers=self.processor.headers
        )

    @patch('requests.get')
    def test_server_not_exists(self, mock_get):
        """server_exists 메서드 테스트 - 서버가 존재하지 않는 경우"""
        # 서버가 존재하지 않는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {"list": [], "page": {"totalElements": 0}}
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.processor.server_exists("non_existing_server")

        # 결과 확인
        self.assertIsNone(result)

    @patch('requests.post')
    def test_add_server(self, mock_post):
        """add_server 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "uuid": "new-server-uuid",
            "name": "new_server",
            "host": "10.10.10.10",
            "osType": "AWS_LINUX"
        }
        mock_post.return_value = mock_response

        # 테스트 데이터
        server_data = {
            "host": "10.10.10.10",
            "name": "new_server",
            "osType": "AWS_LINUX",
            "sshPort": 22
        }

        # 테스트 실행
        result = self.processor.add_server(server_data)

        # 결과 확인
        self.assertEqual(result, "new-server-uuid")
        mock_post.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/servers",
            headers=self.processor.headers,
            json=server_data
        )

    @patch('requests.get')
    def test_get_secret_store_uuid(self, mock_get):
        """get_secret_store_uuid 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = [
            {"name": "Secret Store 1", "uuid": "secret-store-uuid"}
        ]
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.processor.get_secret_store_uuid()

        # 결과 확인
        self.assertEqual(result, "secret-store-uuid")
        self.assertEqual(self.processor.secret_store_uuid, "secret-store-uuid")  # 캐시 확인
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/security/secret-stores",
            headers=self.processor.headers
        )

        # 두 번째 호출은 캐시된 값을 반환해야 함
        mock_get.reset_mock()
        result = self.processor.get_secret_store_uuid()
        self.assertEqual(result, "secret-store-uuid")
        mock_get.assert_not_called()  # API 호출이 발생하지 않아야 함

    @patch('requests.post')
    def test_add_server_tag(self, mock_post):
        """add_server_tag 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_post.return_value = mock_response

        # 테스트 실행
        result = self.processor.add_server_tag("server-uuid", "test-key", "test-value")

        # 결과 확인
        self.assertTrue(result)
        mock_post.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/servers/server-uuid/tags",
            headers=self.processor.headers,
            json={
                "customTags": [
                    {
                        "key": "test-key",
                        "value": "test-value"
                    }
                ],
                "overwrite": True
            }
        )

class TestProcessServerCSV(unittest.TestCase):
    """process_server_csv 함수 테스트"""

    def setUp(self):
        """테스트 설정"""
        # 임시 CSV 파일 생성
        self.temp_dir = tempfile.mkdtemp()
        self.csv_file = os.path.join(self.temp_dir, "test_servers.csv")

        with open(self.csv_file, "w", encoding="utf-8") as f:
            f.write("host,name,osType,sshport,server_group,account_name\n")
            f.write("10.10.10.10,server1,AWS_LINUX,22,WEB_GROUP,ec2-user\n")
            f.write("10.10.10.11,server2,AWS_LINUX,22,WEB_GROUP,ec2-user\n")

        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"

    def tearDown(self):
        """테스트 정리"""
        # 임시 파일 삭제
        if os.path.exists(self.csv_file):
            os.remove(self.csv_file)
        if os.path.exists(self.temp_dir):
            os.rmdir(self.temp_dir)

    @patch('server_processor.ServerProcessor')
    def test_process_server_csv(self, MockServerProcessor):
        """process_server_csv 함수 테스트"""
        # ServerProcessor 모의 객체 설정
        mock_processor = MagicMock()
        MockServerProcessor.return_value = mock_processor

        # server_exists 메서드가 첫 번째 서버는 이미 존재하고, 두 번째 서버는 존재하지 않도록 설정
        mock_processor.server_exists.side_effect = ["server1-uuid", None]

        # add_server 메서드는 성공적으로 서버를 추가하도록 설정
        mock_processor.add_server.return_value = "server2-uuid"

        # add_server_tag 메서드는 항상 성공하도록 설정
        mock_processor.add_server_tag.return_value = True

        # get_secret_store_uuid 메서드는 Secret Store UUID를 반환하도록 설정
        mock_processor.get_secret_store_uuid.return_value = "secret-store-uuid"

        # server_group_exists 메서드는 서버 그룹이 존재하지 않도록 설정
        mock_processor.server_group_exists.return_value = None

        # add_server_group 메서드는 성공적으로 서버 그룹을 추가하도록 설정
        mock_processor.add_server_group.return_value = "server-group-uuid"

        # add_server_group_account 메서드는 성공적으로 계정을 추가하도록 설정
        mock_processor.add_server_group_account.return_value = "account-uuid"

        # 테스트 실행
        result = process_server_csv(self.csv_file, self.api_url, self.api_key)

        # 결과 확인
        self.assertTrue(result)

        # server_exists가 두 번 호출되었는지 확인
        self.assertEqual(mock_processor.server_exists.call_count, 2)

        # add_server가 한 번만 호출되었는지 확인 (두 번째 서버만)
        self.assertEqual(mock_processor.add_server.call_count, 1)
        expected_server_data = {
            "host": "10.10.10.11",
            "name": "server2",
            "osType": "AWS_LINUX",
            "sshPort": 22
        }
        mock_processor.add_server.assert_called_once_with(expected_server_data)

        # add_server_tag가 총 4번 호출되었는지 확인 (각 서버마다 2번씩)
        self.assertEqual(mock_processor.add_server_tag.call_count, 4)

        # server_group_exists가 한 번 호출되었는지 확인
        self.assertEqual(mock_processor.server_group_exists.call_count, 1)

        # add_server_group이 한 번 호출되었는지 확인
        self.assertEqual(mock_processor.add_server_group.call_count, 1)

        # add_server_group_account가 한 번 호출되었는지 확인
        self.assertEqual(mock_processor.add_server_group_account.call_count, 1)

if __name__ == '__main__':
    unittest.main()
