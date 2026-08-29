#!/usr/bin/env python3
"""
역할 할당 프로세서 테스트
"""

import unittest
import tempfile
import os
from unittest.mock import patch, MagicMock
from role_assigner import process_role_assignment, RoleAssigner

class TestRoleAssigner(unittest.TestCase):
    """RoleAssigner 클래스 테스트"""

    def setUp(self):
        """테스트 설정"""
        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"
        self.assigner = RoleAssigner(self.api_url, self.api_key)

    @patch('requests.get')
    def test_find_user(self, mock_get):
        """find_user 메서드 테스트"""
        # 사용자가 존재하는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [{"loginId": "existing_user", "uuid": "user-uuid"}],
            "page": {"totalElements": 1}
        }
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.assigner.find_user("existing_user")

        # 결과 확인
        self.assertEqual(result, "user-uuid")
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/users?loginId=existing_user",
            headers=self.assigner.headers
        )

    @patch('requests.get')
    def test_find_user_not_exists(self, mock_get):
        """find_user 메서드 테스트 - 사용자가 존재하지 않는 경우"""
        # 사용자가 존재하지 않는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {"list": [], "page": {"totalElements": 0}}
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.assigner.find_user("non_existing_user")

        # 결과 확인
        self.assertIsNone(result)

    @patch('requests.get')
    def test_find_role(self, mock_get):
        """find_role 메서드 테스트"""
        # 역할이 존재하는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [{"name": "existing_role", "uuid": "role-uuid"}]
        }
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.assigner.find_role("existing_role")

        # 결과 확인
        self.assertEqual(result, "role-uuid")
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/roles?name=existing_role",
            headers=self.assigner.headers
        )

    @patch('requests.get')
    def test_find_role_not_exists(self, mock_get):
        """find_role 메서드 테스트 - 역할이 존재하지 않는 경우"""
        # 역할이 존재하지 않는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {"list": []}
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.assigner.find_role("non_existing_role")

        # 결과 확인
        self.assertIsNone(result)

    @patch('requests.get')
    def test_get_user_roles(self, mock_get):
        """get_user_roles 메서드 테스트"""
        # 사용자에게 할당된 역할이 있는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [
                {"serverRoleUuid": "role1-uuid"},
                {"serverRoleUuid": "role2-uuid"}
            ]
        }
        mock_get.return_value = mock_response

        # 테스트 실행
        result = self.assigner.get_user_roles("user-uuid")

        # 결과 확인
        self.assertEqual(result, {"role1-uuid", "role2-uuid"})
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/access-controls/user-uuid/roles",
            headers=self.assigner.headers
        )

    @patch('datetime.date')
    @patch('requests.post')
    def test_assign_role(self, mock_post, mock_date):
        """assign_role 메서드 테스트"""
        # 날짜 모의
        today = MagicMock()
        today.year = 2023
        today_replace_mock = MagicMock()
        today_replace_mock.isoformat.return_value = '2023-11-06T00:00:00Z'
        today.replace.return_value = today_replace_mock
        mock_date.today.return_value = today

        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_post.return_value = mock_response

        # 테스트 실행
        result = self.assigner.assign_role("user-uuid", "role-uuid")

        # 결과 확인
        self.assertTrue(result)
        mock_post.assert_called_once()

        # 호출 인자 확인
        call_args = mock_post.call_args
        url = call_args[0][0]
        self.assertEqual(url, f"{self.api_url}/api/external/v2/sac/access-controls/user-uuid/roles")

        # 캐시 업데이트 확인
        self.assertIn("user-uuid", self.assigner.assigned_roles)
        self.assertIn("role-uuid", self.assigner.assigned_roles["user-uuid"])

class TestProcessRoleAssignment(unittest.TestCase):
    """process_role_assignment 함수 테스트"""

    def setUp(self):
        """테스트 설정"""
        # 임시 CSV 파일 생성
        self.temp_dir = tempfile.mkdtemp()
        self.csv_file = os.path.join(self.temp_dir, "test_users.csv")

        with open(self.csv_file, "w", encoding="utf-8") as f:
            f.write("email,loginId,name,password,role\n")
            f.write("test1@example.com,test1,Test User 1,password1,ADMIN\n")
            f.write("test2@example.com,test2,Test User 2,password2,USER\n")
            f.write("test3@example.com,test3,Test User 3,password3,ADMIN;USER;MANAGER\n")

        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"

    def tearDown(self):
        """테스트 정리"""
        # 임시 파일 삭제
        if os.path.exists(self.csv_file):
            os.remove(self.csv_file)
        if os.path.exists(self.temp_dir):
            os.rmdir(self.temp_dir)

    @patch('role_assigner.RoleAssigner')
    def test_process_role_assignment(self, MockRoleAssigner):
        """process_role_assignment 함수 테스트"""
        # RoleAssigner 모의 객체 설정
        mock_assigner = MagicMock()
        MockRoleAssigner.return_value = mock_assigner

        # find_user 메서드가 사용자를 찾도록 설정
        mock_assigner.find_user.side_effect = ["user1-uuid", "user2-uuid", "user3-uuid"]

        # find_role 메서드가 역할을 찾거나 찾지 못하도록 설정
        mock_assigner.find_role.side_effect = [
            "admin-role-uuid",    # test1의 ADMIN 역할
            None,                 # test2의 USER 역할 (찾지 못함)
            "admin-role-uuid",    # test3의 ADMIN 역할
            "user-role-uuid",     # test3의 USER 역할
            "manager-role-uuid"   # test3의 MANAGER 역할
        ]

        # get_user_roles 메서드가 기존 역할을 반환하도록 설정
        # 첫 번째 사용자는 역할이 없음
        # 세 번째 사용자는 ADMIN 역할이 이미 있음
        mock_assigner.get_user_roles.side_effect = [
            set(),                       # test1 (역할 없음)
            set(),                       # test2 (역할 없음)
            {"admin-role-uuid"},         # test3 (ADMIN 역할 이미 있음)
        ]

        # assign_role 메서드는 성공적으로 역할을 할당하도록 설정
        mock_assigner.assign_role.side_effect = [True, True, True]

        # 테스트 실행
        result = process_role_assignment(self.csv_file, self.api_url, self.api_key)

        # 결과 확인
        self.assertTrue(result)

        # 메서드 호출 확인
        self.assertEqual(mock_assigner.find_user.call_count, 3)
        self.assertEqual(mock_assigner.find_role.call_count, 5)
        self.assertEqual(mock_assigner.get_user_roles.call_count, 3)
        self.assertEqual(mock_assigner.assign_role.call_count, 3)

        # 첫 번째 사용자에 대한 호출 확인
        mock_assigner.find_user.assert_any_call("test1")
        mock_assigner.find_role.assert_any_call("ADMIN role")

        # 두 번째 사용자에 대한 호출 확인
        mock_assigner.find_user.assert_any_call("test2")
        mock_assigner.find_role.assert_any_call("USER role")

        # 세 번째 사용자에 대한 호출 확인
        mock_assigner.find_user.assert_any_call("test3")
        mock_assigner.find_role.assert_any_call("ADMIN role")
        mock_assigner.find_role.assert_any_call("USER role")
        mock_assigner.find_role.assert_any_call("MANAGER role")

        # 역할 할당 호출 확인
        mock_assigner.assign_role.assert_any_call("user1-uuid", "admin-role-uuid")
        mock_assigner.assign_role.assert_any_call("user3-uuid", "user-role-uuid")
        mock_assigner.assign_role.assert_any_call("user3-uuid", "manager-role-uuid")

    @patch('role_assigner.RoleAssigner')
    def test_process_empty_role(self, MockRoleAssigner):
        """빈 역할 값이나 공백만 있는 역할 값 처리 테스트"""
        # 빈 역할 값이나 공백만 있는 역할 값을 가진 CSV 파일 생성
        empty_role_csv = os.path.join(self.temp_dir, "empty_roles.csv")
        with open(empty_role_csv, "w", encoding="utf-8") as f:
            f.write("email,loginId,name,password,role\n")
            f.write("test1@example.com,test1,Test User 1,password1,\n")
            f.write("test2@example.com,test2,Test User 2,password2,  \n")
            f.write("test3@example.com,test3,Test User 3,password3,;\n")
            f.write("test4@example.com,test4,Test User 4,password4,  ;  \n")

        # RoleAssigner 모의 객체 설정
        mock_assigner = MagicMock()
        MockRoleAssigner.return_value = mock_assigner

        # 테스트 실행
        result = process_role_assignment(empty_role_csv, self.api_url, self.api_key)

        # 결과 확인
        self.assertTrue(result)

        # find_user 메서드가 호출되지 않아야 함 (빈 역할 값은 건너뛰기 됨)
        mock_assigner.find_user.assert_not_called()
        mock_assigner.find_role.assert_not_called()
        mock_assigner.get_user_roles.assert_not_called()
        mock_assigner.assign_role.assert_not_called()

        # 임시 파일 삭제
        if os.path.exists(empty_role_csv):
            os.remove(empty_role_csv)

if __name__ == '__main__':
    unittest.main()
