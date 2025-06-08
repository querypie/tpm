#!/usr/bin/env python3
"""
사용자 프로세서 테스트
"""

import unittest
import tempfile
import os
from unittest.mock import patch, MagicMock
from user_processor import process_users_csv, UserProcessor

class TestUserProcessor(unittest.TestCase):
    """UserProcessor 클래스 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"
        self.processor = UserProcessor(self.api_url, self.api_key)

    @patch('requests.get')
    def test_user_exists(self, mock_get):
        """user_exists 메서드 테스트"""
        # 사용자가 존재하는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [{"loginId": "existing_user", "uuid": "user-uuid"}],
            "page": {"totalElements": 1}
        }
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.processor.user_exists("existing_user")

        # 결과 확인
        self.assertTrue(result)
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/users?loginId=existing_user",
            headers=self.processor.headers
        )

    @patch('requests.get')
    def test_user_not_exists(self, mock_get):
        """user_exists 메서드 테스트 - 사용자가 존재하지 않는 경우"""
        # 사용자가 존재하지 않는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {"list": [], "page": {"totalElements": 0}}
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.processor.user_exists("non_existing_user")

        # 결과 확인
        self.assertFalse(result)

    @patch('requests.post')
    def test_add_user(self, mock_post):
        """add_user 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "uuid": "new-user-uuid",
            "loginId": "new_user",
            "email": "new_user@example.com",
            "name": "New User"
        }
        mock_post.return_value = mock_response

        # 테스트 데이터
        user_data = {
            "email": "new_user@example.com",
            "loginId": "new_user",
            "name": "New User",
            "password": "password123"
        }

        # 테스트 실행
        result = self.processor.add_user(user_data)

        # 결과 확인
        self.assertEqual(result["uuid"], "new-user-uuid")
        mock_post.assert_called_once_with(
            f"{self.api_url}/api/external/v2/users",
            headers=self.processor.headers,
            json=user_data
        )

class TestProcessUsersCSV(unittest.TestCase):
    """process_users_csv 함수 테스트"""

    def setUp(self):
        """테스트 설정"""
        # 임시 CSV 파일 생성
        self.temp_dir = tempfile.mkdtemp()
        self.csv_file = os.path.join(self.temp_dir, "test_users.csv")

        with open(self.csv_file, "w", encoding="utf-8") as f:
            f.write("email,loginId,name,password,role\n")
            f.write("test1@example.com,test1,Test User 1,password1,USER\n")
            f.write("test2@example.com,test2,Test User 2,password2,ADMIN\n")

        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"

    def tearDown(self):
        """테스트 정리"""
        # 임시 파일 삭제
        if os.path.exists(self.csv_file):
            os.remove(self.csv_file)
        if os.path.exists(self.temp_dir):
            os.rmdir(self.temp_dir)

    @patch('user_processor.UserProcessor')
    def test_process_users_csv(self, MockUserProcessor):
        """process_users_csv 함수 테스트"""
        # UserProcessor 모의 객체 설정
        mock_processor = MagicMock()
        MockUserProcessor.return_value = mock_processor

        # user_exists 메서드가 첫 번째 사용자는 이미 존재하고, 두 번째 사용자는 존재하지 않도록 설정
        mock_processor.user_exists.side_effect = [True, False]

        # add_user 메서드는 성공적으로 사용자를 추가하도록 설정
        mock_processor.add_user.return_value = {"uuid": "new-user-uuid"}

        # 테스트 실행
        result = process_users_csv(self.csv_file, self.api_url, self.api_key)

        # 결과 확인
        self.assertTrue(result)

        # user_exists가 두 번 호출되었는지 확인
        self.assertEqual(mock_processor.user_exists.call_count, 2)

        # add_user가 한 번만 호출되었는지 확인 (두 번째 사용자만)
        self.assertEqual(mock_processor.add_user.call_count, 1)

        # 두 번째 사용자에 대해 add_user가 올바른 데이터로 호출되었는지 확인
        expected_user_data = {
            "email": "test2@example.com",
            "loginId": "test2",
            "name": "Test User 2",
            "password": "password2",
            "role": ["ADMIN"]
        }
        mock_processor.add_user.assert_called_once_with(expected_user_data)

if __name__ == '__main__':
    unittest.main()
