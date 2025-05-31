#!/usr/bin/env python3
"""
정책 프로세서 테스트
"""

import unittest
import tempfile
import os
from unittest.mock import patch, MagicMock
from policy_processor import process_policies_from_csv, PolicyProcessor

class TestPolicyProcessor(unittest.TestCase):
    """PolicyProcessor 클래스 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"
        self.processor = PolicyProcessor(self.api_url, self.api_key)
    
    @patch('requests.get')
    def test_policy_exists(self, mock_get):
        """policy_exists 메서드 테스트"""
        # 정책이 존재하는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [{"name": "existing_policy", "uuid": "policy-uuid"}],
            "page": {"totalElements": 1}
        }
        mock_get.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.policy_exists("existing_policy")
        
        # 결과 확인
        self.assertEqual(result, "policy-uuid")
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/policies?name=existing_policy",
            headers=self.processor.headers
        )
    
    @patch('requests.get')
    def test_policy_not_exists(self, mock_get):
        """policy_exists 메서드 테스트 - 정책이 존재하지 않는 경우"""
        # 정책이 존재하지 않는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {"list": [], "page": {"totalElements": 0}}
        mock_get.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.policy_exists("non_existing_policy")
        
        # 결과 확인
        self.assertIsNone(result)
    
    @patch('requests.post')
    def test_add_policy(self, mock_post):
        """add_policy 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "uuid": "new-policy-uuid"
        }
        mock_post.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.add_policy("new_policy", "New Policy Description")
        
        # 결과 확인
        self.assertEqual(result, "new-policy-uuid")
        mock_post.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/policies",
            headers=self.processor.headers,
            json={
                "name": "new_policy",
                "description": "New Policy Description"
            }
        )
    
    @patch('requests.put')
    def test_update_policy_content(self, mock_put):
        """update_policy_content 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_put.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.update_policy_content(
            "policy-uuid",
            "test-group",
            ["account1"],
            "test-justification"
        )
        
        # 결과 확인
        self.assertTrue(result)
        mock_put.assert_called_once()
        
        # 여러 계정으로 테스트
        mock_put.reset_mock()
        result = self.processor.update_policy_content(
            "policy-uuid",
            "test-group",
            ["account1", "account2"],
            "test-justification"
        )
        
        # 결과 확인
        self.assertTrue(result)
        mock_put.assert_called_once()
    
    @patch('requests.get')
    def test_role_exists(self, mock_get):
        """role_exists 메서드 테스트"""
        # 역할이 존재하는 경우 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "list": [{"name": "existing_role", "uuid": "role-uuid"}]
        }
        mock_get.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.role_exists("existing_role")
        
        # 결과 확인
        self.assertEqual(result, "role-uuid")
        mock_get.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/roles",
            headers=self.processor.headers
        )
    
    @patch('requests.post')
    def test_add_role(self, mock_post):
        """add_role 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "uuid": "new-role-uuid"
        }
        mock_post.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.add_role("new_role", "New Role Description")
        
        # 결과 확인
        self.assertEqual(result, "new-role-uuid")
        mock_post.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/roles",
            headers=self.processor.headers,
            json={
                "name": "new_role",
                "description": "New Role Description"
            }
        )
    
    @patch('requests.post')
    def test_add_policies_to_role(self, mock_post):
        """add_policies_to_role 메서드 테스트"""
        # 성공적인 응답 모의
        mock_response = MagicMock()
        mock_post.return_value = mock_response
        
        # 테스트 실행
        result = self.processor.add_policies_to_role(
            "role-uuid",
            ["policy-uuid1", "policy-uuid2"]
        )
        
        # 결과 확인
        self.assertTrue(result)
        mock_post.assert_called_once_with(
            f"{self.api_url}/api/external/v2/sac/roles/role-uuid/policies",
            headers=self.processor.headers,
            json={
                "serverPolicyIdentifiers": ["policy-uuid1", "policy-uuid2"]
            }
        )

class TestProcessPoliciesFromCSV(unittest.TestCase):
    """process_policies_from_csv 함수 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        # 임시 CSV 파일 생성
        self.temp_dir = tempfile.mkdtemp()
        self.csv_file = os.path.join(self.temp_dir, "test_servers.csv")
        
        with open(self.csv_file, "w", encoding="utf-8") as f:
            f.write("host,name,osType,sshport,server_group,account_name\n")
            f.write("10.10.10.10,server1,AWS_LINUX,22,WEB_GROUP,account1\n")
            f.write("10.10.10.11,server2,AWS_LINUX,22,WEB_GROUP,account2\n")
            f.write("10.10.10.12,server3,CENTOS,22,DB_GROUP,account3\n")
        
        self.api_url = "https://api.example.com"
        self.api_key = "test-api-key"
    
    def tearDown(self):
        """테스트 정리"""
        # 임시 파일 삭제
        if os.path.exists(self.csv_file):
            os.remove(self.csv_file)
        if os.path.exists(self.temp_dir):
            os.rmdir(self.temp_dir)
    
    @patch('policy_processor.PolicyProcessor')
    def test_process_policies_from_csv(self, MockPolicyProcessor):
        """process_policies_from_csv 함수 테스트"""
        # PolicyProcessor 모의 객체 설정
        mock_processor = MagicMock()
        MockPolicyProcessor.return_value = mock_processor
        
        # policy_exists 메서드가 정책이 존재하지 않도록 설정
        mock_processor.policy_exists.return_value = None
        
        # add_policy 메서드는 정책 UUID를 반환하도록 설정
        mock_processor.add_policy.side_effect = ["policy1-uuid", "policy2-uuid"]
        
        # update_policy_content 메서드는 항상 성공하도록 설정
        mock_processor.update_policy_content.return_value = True
        
        # role_exists 메서드가 역할이 존재하지 않도록 설정
        mock_processor.role_exists.return_value = None
        
        # add_role 메서드는 역할 UUID를 반환하도록 설정
        mock_processor.add_role.side_effect = ["role1-uuid", "role2-uuid"]
        
        # add_policies_to_role 메서드는 항상 성공하도록 설정
        mock_processor.add_policies_to_role.return_value = True
        
        # 테스트 실행
        result = process_policies_from_csv(self.csv_file, self.api_url, self.api_key)
        
        # 결과 확인
        self.assertTrue(result)
        
        # 정확한 수의 호출이 이루어졌는지 확인
        self.assertEqual(mock_processor.policy_exists.call_count, 2)  # 두 개의 서버 그룹이 있음
        self.assertEqual(mock_processor.add_policy.call_count, 2)     # 두 개의 정책이 생성됨
        self.assertEqual(mock_processor.update_policy_content.call_count, 2)  # 두 개의 정책 내용이 업데이트됨
        self.assertEqual(mock_processor.role_exists.call_count, 2)    # 두 개의 역할을 확인함
        self.assertEqual(mock_processor.add_role.call_count, 2)       # 두 개의 역할이 생성됨
        self.assertEqual(mock_processor.add_policies_to_role.call_count, 2)  # 두 개의 역할에 정책이 추가됨

if __name__ == '__main__':
    unittest.main() 