#!/usr/bin/env python3
"""
사용자 및 서버 CSV 파일을 처리하여 등록, 서버 그룹 생성, 정책 및 역할 관리, 역할 할당까지 모든 과정을 순차적으로 수행하는 프로그램
"""

import os
import sys
import argparse
import logging
import subprocess
import time

def run_process(command, description):
    """
    주어진 명령을 실행하고 결과를 반환
    
    Args:
        command (list): 실행할 명령 (subprocess.run에 전달할 형식)
        description (str): 명령에 대한 설명
        
    Returns:
        bool: 성공 여부
    """
    logger = logging.getLogger(__name__)
    
    logger.info(f"{description} 시작")
    try:
        result = subprocess.run(
            command,
            stdout=None,  # stdout을 None으로 설정하여 터미널에 직접 출력
            stderr=None,  # stderr을 None으로 설정하여 터미널에 직접 출력
            text=True,
            check=False  # 명령이 실패해도 예외를 발생시키지 않음
        )
        
        if result.returncode == 0:
            logger.info(f"{description} 성공")
            return True
        else:
            logger.error(f"{description} 실패")
            return False
    except Exception as e:
        logger.error(f"{description} 실행 중 오류 발생: {str(e)}")
        return False

def main():
    # 로깅 설정
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    # 명령행 인자 파싱
    parser = argparse.ArgumentParser(
        description='사용자 및 서버 CSV 파일을 처리하여 모든 과정을 순차적으로 수행합니다.'
    )
    parser.add_argument('users_csv', help='사용자 정보가 담긴 CSV 파일 경로')
    parser.add_argument('servers_csv', help='서버 정보가 담긴 CSV 파일 경로')
    parser.add_argument('--api-url', dest='api_url', default=os.environ.get('API_BASE_URL'), 
                        help='API 기본 URL (기본값: 환경 변수 API_BASE_URL)')
    parser.add_argument('--api-key', dest='api_key', default=os.environ.get('API_KEY'),
                        help='API 인증 키 (기본값: 환경 변수 API_KEY)')
    
    args = parser.parse_args()
    
    # 필수 매개변수 확인
    if not args.users_csv or not args.servers_csv:
        logger.error("사용자 CSV 파일과 서버 CSV 파일 모두 필요합니다.")
        parser.print_help()
        return 1
    
    if not args.api_url:
        logger.error("API 기본 URL이 필요합니다. --api-url 옵션을 사용하거나 API_BASE_URL 환경 변수를 설정하세요.")
        parser.print_help()
        return 1
    
    if not args.api_key:
        logger.error("API 키가 필요합니다. --api-key 옵션을 사용하거나 API_KEY 환경 변수를 설정하세요.")
        parser.print_help()
        return 1
    
    # CSV 파일 존재 확인
    if not os.path.isfile(args.users_csv):
        logger.error(f"사용자 CSV 파일을 찾을 수 없습니다: {args.users_csv}")
        return 1
    
    if not os.path.isfile(args.servers_csv):
        logger.error(f"서버 CSV 파일을 찾을 수 없습니다: {args.servers_csv}")
        return 1
    
    logger.info("모든 처리 프로세스 시작")
    logger.info(f"API URL: {args.api_url}")
    logger.info(f"사용자 CSV 파일: {args.users_csv}")
    logger.info(f"서버 CSV 파일: {args.servers_csv}")
    
    # 공통 명령 인자
    api_args = [
        '--api-url', args.api_url,
        '--api-key', args.api_key
    ]
    
    # 1. 사용자 등록 처리
    user_cmd = [sys.executable, 'process_users.py', args.users_csv] + api_args
    if not run_process(user_cmd, "사용자 등록 처리"):
        logger.error("사용자 등록 처리 실패로 전체 프로세스를 중단합니다.")
        return 1
    
    # 처리 간 딜레이 (API 호출 부하 방지)
    time.sleep(1)
    
    # 2. 서버 등록 및 그룹 처리
    server_cmd = [sys.executable, 'process_servers.py', args.servers_csv] + api_args
    if not run_process(server_cmd, "서버 등록 및 그룹 처리"):
        logger.error("서버 등록 처리 실패로 전체 프로세스를 중단합니다.")
        return 1
    
    # 처리 간 딜레이 (API 호출 부하 방지)
    time.sleep(1)
    
    # 3. 정책 및 역할 생성 처리
    policy_cmd = [sys.executable, 'process_policies.py', args.servers_csv] + api_args
    if not run_process(policy_cmd, "정책 및 역할 생성 처리"):
        logger.error("정책 및 역할 생성 처리 실패로 전체 프로세스를 중단합니다.")
        return 1
    
    # 처리 간 딜레이 (API 호출 부하 방지)
    time.sleep(1)
    
    # 4. 역할 할당 처리
    role_cmd = [sys.executable, 'process_roles.py', args.users_csv] + api_args
    if not run_process(role_cmd, "역할 할당 처리"):
        logger.error("역할 할당 처리 실패로 전체 프로세스를 중단합니다.")
        return 1
    
    logger.info("모든 처리 프로세스 성공적으로 완료")
    return 0

if __name__ == "__main__":
    sys.exit(main()) 