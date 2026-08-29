#!/usr/bin/env python3
"""
통합 프로세스 테스트
"""

import unittest
import tempfile
import os
from unittest.mock import patch, MagicMock, call

# process_all 모듈을 임포트하기 전에 현재 디렉토리를 테스트용 모듈 검색 경로에 추가합니다.
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from process_all import run_process

class TestProcessAll(unittest.TestCase):
    """통합 프로세스 프로그램 테스트"""
    
    def setUp(self):
        """테스트 설정"""
        # 임시 CSV 파일 생성
        self.temp_dir = tempfile.mkdtemp()
        self.users_csv = os.path.join(self.temp_dir, "test_users.csv")
        self.servers_csv = os.path.join(self.temp_dir, "test_servers.csv")
        
        # 사용자 CSV 파일 생성
        with open(self.users_csv, "w", encoding="utf-8") as f:
            f.write("email,loginId,name,password,role\n")
            f.write("test1@example.com,test1,Test User 1,password1,ADMIN\n")
        
        # 서버 CSV 파일 생성
        with open(self.servers_csv, "w", encoding="utf-8") as f:
            f.write("host,name,osType,sshport,server_group,account_name\n")
            f.write("10.0.0.1,server1,LINUX,22,TEST_GROUP,testuser\n")
    
    def tearDown(self):
        """테스트 정리"""
        # 임시 파일 삭제
        for file_path in [self.users_csv, self.servers_csv]:
            if os.path.exists(file_path):
                os.remove(file_path)
        if os.path.exists(self.temp_dir):
            os.rmdir(self.temp_dir)
    
    @patch('subprocess.run')
    def test_run_process_success(self, mock_run):
        """run_process 함수 성공 테스트"""
        # 성공적인 프로세스 실행 모의
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_run.return_value = mock_result
        
        # 테스트 실행
        command = ["echo", "test"]
        result = run_process(command, "테스트 명령")
        
        # 결과 확인
        self.assertTrue(result)
        mock_run.assert_called_once_with(
            command,
            stdout=unittest.mock.ANY,
            stderr=unittest.mock.ANY,
            text=True,
            check=False
        )
    
    @patch('subprocess.run')
    def test_run_process_failure(self, mock_run):
        """run_process 함수 실패 테스트"""
        # 실패한 프로세스 실행 모의
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stderr = "오류 메시지"
        mock_run.return_value = mock_result
        
        # 테스트 실행
        command = ["echo", "test"]
        result = run_process(command, "테스트 명령")
        
        # 결과 확인
        self.assertFalse(result)
        mock_run.assert_called_once()
    
    @patch('subprocess.run')
    def test_run_process_exception(self, mock_run):
        """run_process 함수 예외 발생 테스트"""
        # 예외 발생 모의
        mock_run.side_effect = Exception("테스트 예외")
        
        # 테스트 실행
        command = ["echo", "test"]
        result = run_process(command, "테스트 명령")
        
        # 결과 확인
        self.assertFalse(result)
        mock_run.assert_called_once()
    
    @patch('process_all.run_process')
    @patch('sys.executable', 'python')
    def test_main_function_success(self, mock_run_process):
        """main 함수의 성공적인 실행 테스트"""
        # 모든 프로세스가 성공적으로 실행되도록 설정
        mock_run_process.return_value = True
        
        # 테스트를 위한 명령행 인자 설정
        test_args = [
            'process_all.py',
            self.users_csv,
            self.servers_csv,
            '--api-url', 'https://api.example.com',
            '--api-key', 'test-api-key'
        ]
        
        # main 함수 실행 모의
        with patch('sys.argv', test_args):
            from process_all import main
            result = main()
        
        # 결과 확인
        self.assertEqual(result, 0)
        
        # 각 프로세스에 대한 호출 확인
        expected_calls = [
            call(['python', 'process_users.py', self.users_csv, '--api-url', 'https://api.example.com', '--api-key', 'test-api-key'], "사용자 등록 처리"),
            call(['python', 'process_servers.py', self.servers_csv, '--api-url', 'https://api.example.com', '--api-key', 'test-api-key'], "서버 등록 및 그룹 처리"),
            call(['python', 'process_policies.py', self.servers_csv, '--api-url', 'https://api.example.com', '--api-key', 'test-api-key'], "정책 및 역할 생성 처리"),
            call(['python', 'process_roles.py', self.users_csv, '--api-url', 'https://api.example.com', '--api-key', 'test-api-key'], "역할 할당 처리")
        ]
        
        self.assertEqual(mock_run_process.call_count, 4)
        mock_run_process.assert_has_calls(expected_calls)
    
    @patch('process_all.run_process')
    def test_main_function_failure(self, mock_run_process):
        """main 함수의 실패 테스트 (두 번째 프로세스 실패)"""
        # 두 번째 프로세스가 실패하도록 설정
        mock_run_process.side_effect = [True, False]
        
        # 테스트를 위한 명령행 인자 설정
        test_args = [
            'process_all.py',
            self.users_csv,
            self.servers_csv,
            '--api-url', 'https://api.example.com',
            '--api-key', 'test-api-key'
        ]
        
        # main 함수 실행 모의
        with patch('sys.argv', test_args):
            from process_all import main
            result = main()
        
        # 결과 확인
        self.assertEqual(result, 1)
        
        # 두 번의 호출만 발생해야 함
        self.assertEqual(mock_run_process.call_count, 2)

if __name__ == '__main__':
    unittest.main() 